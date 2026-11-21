#!/usr/bin/env python3
"""buildapp_scheme_tools.py — URL-scheme contract for customer builds (F09-F13).

Pure-stdlib tool used by scripts/buildapp.sh AND directly by
scripts/buildapp_test.sh. Every subcommand prints a JSON summary on stdout
(one line) and exits 0/1; errors explain themselves on stderr.

Subcommands:
  validate-scheme <value>
      RFC 3986 scheme subset with an explicit case policy: config must
      already be lowercase canonical (we never silently rewrite case).
  inject-android <AndroidManifest.xml> <scheme>
      Replace the vendor deeplink data schemes (android:scheme="imboy")
      with the customer scheme, then structurally verify that every touched
      intent-filter kept VIEW/DEFAULT/BROWSABLE and its host/pathPrefix
      semantics. Refuses to touch anything else (https app links, queries,
      SMS/TEL, third-party callbacks live in other elements).
  verify-android <AndroidManifest.xml> <scheme> [--allow-vendor-imboy]
      Structural assertions on the (injected) manifest.
  inject-ios <Info.plist> <scheme>
      Rewrite ONLY the IMBoy deeplink URL type's CFBundleURLSchemes
      (identified by CFBundleURLName == "imboy.pub"); every other URL type
      (weixin / alipay / ShareMedia), CFBundleDocumentTypes and
      UTImportedTypeDeclarations (E2EE backup) are preserved verbatim.
  verify-ios <Info.plist> <scheme> [--allow-vendor-imboy]
      Structural assertions on the (injected) plist. Works on built
      Runner.app/Info.plist too (plistlib auto-detects binary plists).
  parse-aapt2 <file>
      Parse `aapt2 dump xmltree --file AndroidManifest.xml <apk>` output;
      report activity intent-filter data schemes vs queries schemes.
"""

import json
import plistlib
import re
import sys
import xml.etree.ElementTree as ET

VENDOR_SCHEME = "imboy"
VENDOR_DEEPLINK_HOST = "imboy.pub"
IOS_DEEPLINK_URL_NAME = "imboy.pub"
SCHEME_RE = re.compile(r"^[a-z][a-z0-9+.\-]{0,39}$")
ANDROID_NS = "{http://schemas.android.com/apk/res/android}"


def out(payload):
    print(json.dumps(payload, ensure_ascii=False, sort_keys=False))


def fail(msg, payload=None):
    if payload is not None:
        payload = dict(payload)
        payload["ok"] = False
        payload["errors"] = payload.get("errors", []) + [msg]
        out(payload)
    else:
        out({"ok": False, "errors": [msg]})
    sys.exit(1)


# ---------------------------------------------------------------- scheme
def cmd_validate_scheme(value):
    v = value.strip()
    if not v:
        fail("identity.url_scheme is empty")
    if v != value:
        fail("identity.url_scheme has surrounding whitespace: %r" % value)
    if v != v.lower():
        fail("identity.url_scheme must be lowercase (explicit case policy; got %r)" % v)
    if "://" in v:
        fail("identity.url_scheme must be a bare scheme, not a URL (contains '://'): %r" % v)
    if any(c in v for c in ":/?#"):
        fail("identity.url_scheme must not contain ':' '/' '?' '#' (no host/path/query): %r" % v)
    if not SCHEME_RE.match(v):
        fail("identity.url_scheme %r does not match [a-z][a-z0-9+.-]{0,39} (RFC 3986 scheme, lowercase policy)" % v)
    out({"ok": True, "scheme": v})


def validate_or_die(value):
    if value == VENDOR_SCHEME:
        fail("scheme %r is the vendor scheme; customer builds must register a customer-owned scheme "
             "(or, for demo environments only, explicitly opt into inheritance)" % value)
    v = value.strip()
    if not v or v != value or v != v.lower() or "://" in v or any(c in v for c in ":/?#") or not SCHEME_RE.match(v):
        fail("invalid identity.url_scheme %r" % value)
    return v


# ---------------------------------------------------------------- android
def _data_attr(el, name):
    return el.get(ANDROID_NS + name)


def _activity_filters(root):
    """Yield (activity_name, filter_element) for every activity intent-filter."""
    app = root.find("application")
    if app is None:
        return []
    pairs = []
    for activity in app.findall("activity"):
        name = _data_attr(activity, "name") or "?"
        for flt in activity.findall("intent-filter"):
            pairs.append((name, flt))
    return pairs


def _filter_summary(flt):
    actions = sorted(a.get(ANDROID_NS + "name") for a in flt.findall("action"))
    categories = sorted(c.get(ANDROID_NS + "name") for c in flt.findall("category"))
    datas = [
        {
            "scheme": _data_attr(d, "scheme"),
            "host": _data_attr(d, "host"),
            "pathPrefix": _data_attr(d, "pathPrefix"),
        }
        for d in flt.findall("data")
    ]
    return {
        "autoVerify": _data_attr(flt, "autoVerify"),
        "actions": actions,
        "categories": categories,
        "datas": datas,
        "schemes": sorted({d["scheme"] for d in datas if d["scheme"]}),
    }


def _android_state(path):
    root = ET.parse(path).getroot()
    filters = [
        {"activity": name, **_filter_summary(flt)}
        for name, flt in _activity_filters(root)
    ]
    queries = root.find("queries")
    queries_schemes = []
    if queries is not None:
        for intent in queries.findall("intent"):
            for d in intent.findall("data"):
                s = _data_attr(d, "scheme")
                if s:
                    queries_schemes.append(s)
    activity_schemes = sorted({s for f in filters for s in f["schemes"]})
    return {
        "filters": filters,
        "activity_data_schemes": activity_schemes,
        "queries_schemes": sorted(set(queries_schemes)),
    }


def cmd_inject_android(path, scheme):
    if scheme == VENDOR_SCHEME:
        # Demo builds that explicitly inherit the vendor scheme: no text edit,
        # verify-only pass (caller records vendor-inherited status).
        state = _android_state(path)
        result = _android_checks(state, scheme, allow_vendor=True)
        out({"ok": True, "replaced": 0, "vendor_inherited": True, **state, **result})
        return
    scheme = validate_or_die(scheme)

    with open(path, encoding="utf-8") as fh:
        content = fh.read()
    token = 'android:scheme="%s"' % VENDOR_SCHEME
    replacement = 'android:scheme="%s"' % scheme
    count = content.count(token)
    if count == 0:
        fail("no vendor deeplink data scheme found (%s) — manifest layout changed?" % token)
    if content.count(replacement) and scheme != VENDOR_SCHEME:
        # customer scheme already present pre-injection would make the
        # post-injection uniqueness assertions ambiguous; refuse.
        fail("customer scheme %r already present before injection" % scheme)

    before = _android_state(path)
    before_vendor_filters = [f for f in before["filters"] if VENDOR_SCHEME in f["schemes"]]
    if len(before_vendor_filters) != count:
        fail("vendor scheme token count %d != structurally parsed vendor filters %d" % (count, len(before_vendor_filters)))

    content = content.replace(token, replacement)
    with open(path, "w", encoding="utf-8") as fh:
        fh.write(content)

    after = _android_state(path)
    after_customer = [f for f in after["filters"] if scheme in f["schemes"]]
    # structural equivalence: every vendor filter must map 1:1 onto a customer
    # filter that is identical except scheme value imboy -> <scheme>
    def canon(f, old, new):
        g = json.loads(json.dumps(f))
        for d in g["datas"]:
            if d["scheme"] == old:
                d["scheme"] = new
        g["schemes"] = sorted({d["scheme"] for d in g["datas"] if d["scheme"]})
        return g

    expected = sorted((json.dumps(canon(f, VENDOR_SCHEME, scheme)) for f in before_vendor_filters))
    actual = sorted(json.dumps(f) for f in after_customer)
    if expected != actual:
        fail("structural drift: injected filters differ from vendor filters beyond the scheme value",
             {"before_vendor": before_vendor_filters, "after_customer": after_customer})

    result = _android_checks(after, scheme, allow_vendor=False)
    payload = {"ok": True, "replaced": count, "vendor_inherited": False,
               "imboy_scheme_remaining": VENDOR_SCHEME in after["activity_data_schemes"]}
    payload.update(after)
    payload.update(result)
    if payload["imboy_scheme_remaining"]:
        fail("vendor scheme still registered in activity filters after injection", payload)
    out(payload)


def _android_checks(state, scheme, allow_vendor):
    errors = []
    filters = state["filters"]
    activity_schemes = state["activity_data_schemes"]
    deeplink = [f for f in filters if scheme in f["schemes"]]
    if not deeplink:
        errors.append("customer scheme %r not registered in any activity intent-filter" % scheme)
    for f in deeplink:
        if "android.intent.action.VIEW" not in f["actions"]:
            errors.append("VIEW action missing in a %r filter" % scheme)
        for cat in ("android.intent.category.DEFAULT", "android.intent.category.BROWSABLE"):
            if cat not in f["categories"]:
                errors.append("category %s missing in a %r filter" % (cat.rsplit(".", 1)[-1], scheme))
    if not allow_vendor and VENDOR_SCHEME in activity_schemes:
        errors.append("vendor scheme %r still registered in activity intent-filters" % VENDOR_SCHEME)
    https = [f for f in filters if "https" in f["schemes"]]
    https_ok = bool(https) and all(
        f["autoVerify"] == "true"
        and any(d["host"] == VENDOR_DEEPLINK_HOST for d in f["datas"])
        for f in https
    )
    if not https_ok:
        errors.append("HTTPS App Link registration (autoVerify, host %s) not intact" % VENDOR_DEEPLINK_HOST)
    for s in ("https", "sms", "tel"):
        if s not in state["queries_schemes"]:
            errors.append("queries scheme %r missing (SMS/TEL/visibility contract)" % s)
    main = [f for f in filters
            if "android.intent.action.MAIN" in f["actions"]
            and "android.intent.category.LAUNCHER" in f["categories"]]
    if not main:
        errors.append("MAIN/LAUNCHER filter missing")
    hosts_ok = all(
        all(d["host"] in (None, VENDOR_DEEPLINK_HOST) for d in f["datas"])
        for f in deeplink
    )
    if not hosts_ok:
        errors.append("host semantics changed in a customer filter (expected host %s or none)" % VENDOR_DEEPLINK_HOST)
    return {
        "https_app_link_intact": https_ok,
        "queries_intact": all(s in state["queries_schemes"] for s in ("https", "sms", "tel")),
        "main_launcher_present": bool(main),
        "host_semantics_preserved": hosts_ok,
        "errors": errors,
    }


def cmd_verify_android(path, scheme, allow_vendor):
    state = _android_state(path)
    checks = _android_checks(state, scheme, allow_vendor=allow_vendor)
    payload = {"ok": True, "vendor_inherited": allow_vendor}
    payload.update(state)
    payload.update(checks)
    payload["ok"] = not checks["errors"]
    if checks["errors"]:
        out(payload)
        sys.exit(1)
    out(payload)


# ---------------------------------------------------------------- ios
def _ios_types(plist):
    return plist.get("CFBundleURLTypes") or []


def _ios_deeplink_type(plist):
    matches = [t for t in _ios_types(plist)
               if t.get("CFBundleURLName") == IOS_DEEPLINK_URL_NAME]
    if len(matches) != 1:
        return None
    return matches[0]


def cmd_inject_ios(path, scheme):
    if scheme == VENDOR_SCHEME:
        with open(path, "rb") as fh:
            plist = plistlib.load(fh)
        t = _ios_deeplink_type(plist)
        if t is None or VENDOR_SCHEME not in (t.get("CFBundleURLSchemes") or []):
            fail("vendor-inherited demo build but no %r URL type with scheme %r found" % (IOS_DEEPLINK_URL_NAME, VENDOR_SCHEME))
        out({"ok": True, "replaced": 0, "vendor_inherited": True,
             "url_type_count": len(_ios_types(plist)),
             "deeplink_schemes": t.get("CFBundleURLSchemes")})
        return
    scheme = validate_or_die(scheme)

    with open(path, "rb") as fh:
        plist = plistlib.load(fh)
    types = _ios_types(plist)
    target = _ios_deeplink_type(plist)
    if target is None:
        fail("IMBoy deeplink URL type (CFBundleURLName=%r) not found or ambiguous" % IOS_DEEPLINK_URL_NAME)
    before_other = [t for t in types if t is not target]
    if scheme in [s for t in before_other for s in (t.get("CFBundleURLSchemes") or [])]:
        fail("customer scheme %r collides with an existing non-deeplink URL type scheme" % scheme)

    target["CFBundleURLSchemes"] = [scheme]
    with open(path, "wb") as fh:
        plistlib.dump(plist, fh, fmt=plistlib.FMT_XML, sort_keys=False)

    with open(path, "rb") as fh:
        after = plistlib.load(fh)
    after_types = _ios_types(after)
    after_target = _ios_deeplink_type(after)
    after_other = [t for t in after_types if t is not after_target]
    if len(after_types) == len(types) and after_other == before_other and (after_target.get("CFBundleURLSchemes") == [scheme]):
        out({"ok": True, "replaced": 1, "vendor_inherited": False,
             "url_type_count": len(after_types),
             "deeplink_schemes": after_target.get("CFBundleURLSchemes"),
             "other_url_types_preserved": [t.get("CFBundleURLName") for t in after_other]})
    else:
        fail("post-injection plist drifted beyond the deeplink CFBundleURLSchemes",
             {"url_type_count": len(after_types)})


def _ios_checks(plist, scheme, allow_vendor):
    errors = []
    types = _ios_types(plist)
    target = _ios_deeplink_type(plist)
    if target is None:
        errors.append("IMBoy deeplink URL type (CFBundleURLName=%r) missing or ambiguous" % IOS_DEEPLINK_URL_NAME)
        schemes = []
    else:
        schemes = target.get("CFBundleURLSchemes") or []
        if schemes != [scheme]:
            errors.append("deeplink URL type schemes %r != [%r]" % (schemes, scheme))
        if target.get("CFBundleTypeRole") != "Editor":
            errors.append("deeplink URL type lost CFBundleTypeRole")
    all_schemes = [s for t in types for s in (t.get("CFBundleURLSchemes") or [])]
    if not allow_vendor and VENDOR_SCHEME in all_schemes:
        errors.append("vendor scheme %r still registered as this app's scheme" % VENDOR_SCHEME)
    names = [t.get("CFBundleURLName") for t in types]
    for expected in ("weixin", "alipay", "pub.imboy.app"):
        if expected not in names:
            errors.append("URL type %r missing (third-party/ShareMedia registration must be preserved)" % expected)
    docs = json.dumps(plist.get("CFBundleDocumentTypes") or [], ensure_ascii=False)
    utis = json.dumps(plist.get("UTImportedTypeDeclarations") or [], ensure_ascii=False)
    if "pub.imboy.e2ee-backup" not in docs:
        errors.append("E2EE backup CFBundleDocumentTypes entry missing")
    if "pub.imboy.e2ee-backup" not in utis:
        errors.append("E2EE backup UTImportedTypeDeclarations entry missing")
    return {
        "url_type_count": len(types),
        "deeplink_schemes": schemes,
        "all_registered_url_schemes": sorted(set(all_schemes)),
        "url_type_names": names,
        "e2ee_backup_preserved": "pub.imboy.e2ee-backup" in docs and "pub.imboy.e2ee-backup" in utis,
        "errors": errors,
    }


def cmd_verify_ios(path, scheme, allow_vendor):
    with open(path, "rb") as fh:
        plist = plistlib.load(fh)
    checks = _ios_checks(plist, scheme, allow_vendor)
    payload = {"ok": not checks["errors"], "vendor_inherited": allow_vendor, "plist": path}
    payload.update(checks)
    if checks["errors"]:
        out(payload)
        sys.exit(1)
    out(payload)


# ---------------------------------------------------------------- aapt2
def cmd_parse_aapt2(path):
    """Parse aapt2 dump xmltree text: activity intent-filter data schemes vs queries."""
    activity_schemes, queries_schemes = [], []
    stack = []  # element names
    with open(path, encoding="utf-8", errors="replace") as fh:
        for line in fh:
            m = re.match(r"^(\s*)E: (\S+)", line)
            if m:
                depth = len(m.group(1)) // 2
                del stack[depth:]
                stack.append(m.group(2))
                continue
            m = re.match(r'^\s*A: android:(\w+)\(0x[0-9a-fA-F]+\)="(.*)"$', line.strip())
            if m and m.group(1) == "scheme" and stack:
                joined = "/".join(stack)
                if "/application/activity/intent-filter/data" in joined:
                    activity_schemes.append(m.group(2))
                elif "/queries/intent/data" in joined:
                    queries_schemes.append(m.group(2))
    if not activity_schemes:
        fail("aapt2 xmltree parse found no activity data schemes (format changed?)")
    out({"ok": True,
         "activity_data_schemes": sorted(set(activity_schemes)),
         "queries_schemes": sorted(set(queries_schemes))})


# ---------------------------------------------------------------- main
def main(argv):
    if len(argv) < 2:
        print(__doc__, file=sys.stderr)
        return 64
    cmd, args = argv[1], argv[2:]
    allow_vendor = "--allow-vendor-imboy" in args
    args = [a for a in args if a != "--allow-vendor-imboy"]
    try:
        if cmd == "validate-scheme" and len(args) == 1:
            cmd_validate_scheme(args[0])
        elif cmd == "inject-android" and len(args) == 2:
            cmd_inject_android(args[0], args[1])
        elif cmd == "verify-android" and len(args) == 2:
            cmd_verify_android(args[0], args[1], allow_vendor)
        elif cmd == "inject-ios" and len(args) == 2:
            cmd_inject_ios(args[0], args[1])
        elif cmd == "verify-ios" and len(args) == 2:
            cmd_verify_ios(args[0], args[1], allow_vendor)
        elif cmd == "parse-aapt2" and len(args) == 1:
            cmd_parse_aapt2(args[0])
        else:
            print(__doc__, file=sys.stderr)
            return 64
    except (OSError, ET.ParseError, plistlib.InvalidFileException) as exc:
        fail("%s: %s" % (type(exc).__name__, exc))
    return 0


if __name__ == "__main__":
    sys.exit(main(sys.argv))
