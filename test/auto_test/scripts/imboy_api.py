#!/usr/bin/env python3
"""imboy 生产 API 调试脚本（只读+邀请操作）。

签名机制：sign = base64(HMAC-SHA512("$did|$vsn|$cos|$pkg", key))
key 取自 imboyapp/.env.pro 的 SOLIDIFIED_KEY（脚本不打印密钥）。
用法：
  python3 imboy_api.py init
  python3 imboy_api.py login <account> <pwd>          # 打印 token
  python3 imboy_api.py my-invitations <account> <pwd> # 我收到的邀请
  python3 imboy_api.py sent-invitations <account> <pwd>
  python3 imboy_api.py accept <account> <pwd> <invitation_id>
  python3 imboy_api.py reject <account> <pwd> <invitation_id>
  python3 imboy_api.py create-invite <account> <pwd> <channel_id> <invitee_uid>
"""
import base64
import hashlib
import hmac
import json
import sys
import urllib.request
import urllib.error

BASE = "https://pro.imboy.pub"
ENV_PRO = "/Users/leeyi/project/imboy.pub/imboyapp/.env.pro"
DID = "auto-test-20260808-001"


def load_key() -> str:
    with open(ENV_PRO) as f:
        for line in f:
            line = line.strip()
            if line.startswith("SOLIDIFIED_KEY="):
                return line.split("=", 1)[1].strip().strip('"').strip("'")
    raise SystemExit("SOLIDIFIED_KEY 未找到")


def sign(vsn: str = "1.0.0-alpha.15", cos: str = "android", pkg: str = "imboy.chat"):
    key = load_key()
    raw = f"{DID}|{vsn}|{cos}|{pkg}"
    sig = base64.b64encode(hmac.new(key.encode(), raw.encode(), hashlib.sha512).digest()).decode()
    return {
        "cos": cos, "vsn": vsn, "pkg": pkg, "did": DID, "sk": "1",
        "method": "sha512", "sign": sig,
        "Content-Type": "application/json",
    }


def req(path: str, headers: dict, body=None, method: str = "GET"):
    url = BASE + path
    data = json.dumps(body).encode() if body is not None else None
    r = urllib.request.Request(url, data=data, headers=headers, method=method)
    try:
        with urllib.request.urlopen(r, timeout=15) as resp:
            return resp.status, json.loads(resp.read().decode())
    except urllib.error.HTTPError as e:
        try:
            return e.code, json.loads(e.read().decode())
        except Exception:
            return e.code, {}


def init_config():
    st, j = req("/api/v1/init", sign())
    print("init:", st, json.dumps(j, ensure_ascii=False)[:300])


def login(account: str, pwd: str) -> str:
    h = sign()
    h["X-Client-Type"] = "mobile"
    body = {
        "type": "account", "account": account, "pwd": hashlib.md5(pwd.encode()).hexdigest(),
        "rsa_encrypt": "0", "did": DID, "cos": "android",
    }
    st, j = req("/api/v1/passport/login", h, body, "POST")
    print("login:", st, json.dumps(j, ensure_ascii=False)[:200])
    if st == 200 and j.get("code") == 0:
        return j.get("payload", {}).get("token")
    return None


def authed(method: str, path: str, account: str, pwd: str, body=None):
    tok = login(account, pwd)
    if not tok:
        return None
    h = sign()
    h["Authorization"] = "Bearer " + tok
    st, j = req(path, h, body, method)
    print(f"{method} {path}: {st} {json.dumps(j, ensure_ascii=False)[:400]}")
    return j


def main():
    if len(sys.argv) < 2:
        raise SystemExit(__doc__)
    cmd = sys.argv[1]
    if cmd == "init":
        init_config()
    elif cmd == "login":
        login(sys.argv[2], sys.argv[3])
    elif cmd == "my-invitations":
        authed("GET", "/api/v1/channel/invitations/my", sys.argv[2], sys.argv[3])
    elif cmd == "sent-invitations":
        authed("GET", "/api/v1/channel/invitations/sent", sys.argv[2], sys.argv[3])
    elif cmd == "accept":
        authed("POST", "/api/v1/channel/invitation/accept", sys.argv[2], sys.argv[3],
               {"invitation_id": sys.argv[4]})
    elif cmd == "reject":
        authed("POST", "/api/v1/channel/invitation/reject", sys.argv[2], sys.argv[3],
               {"invitation_id": sys.argv[4]})
    elif cmd == "create-invite":
        authed("POST", f"/api/v1/channel/{sys.argv[4]}/invitation", sys.argv[2], sys.argv[3],
               {"invitee_uid": sys.argv[5]})
    else:
        raise SystemExit(__doc__)


if __name__ == "__main__":
    main()
