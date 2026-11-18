#!/usr/bin/env python3
"""Reject debug authentication inputs at the supported Web delivery build entry.

Configuration-only check: no build, artifact inspection, authentication or I/O
other than a redacted result. Direct Flutter invocations remain outside scope.
"""

import base64
import binascii
import json
import os
import sys

FORBIDDEN = frozenset({'WEB_E2E_TOKEN', 'WEB_E2E_UID'})


def violations(environment):
    reasons = {'forbidden_environment_key:' + key
               for key in FORBIDDEN if key in environment}
    encoded = environment.get('DART_DEFINES', '')
    if not encoded:
        return sorted(reasons)
    if len(encoded) > 1048576 or len(encoded.split(',')) > 1024:
        return sorted(reasons | {'invalid_dart_defines'})
    for item in encoded.split(','):
        try:
            decoded = base64.b64decode(item, validate=True).decode('utf-8')
            key, separator, _ = decoded.partition('=')
            if not separator or not key.strip():
                raise ValueError('invalid define shape')
        except (binascii.Error, UnicodeError, ValueError):
            reasons.add('invalid_dart_defines')
            continue
        if key.strip() in FORBIDDEN:
            reasons.add('forbidden_dart_define:' + key.strip())
    return sorted(reasons)


def main():
    if len(sys.argv) != 1:
        print('Invalid delivery configuration checker arguments.', file=sys.stderr)
        return 64
    reasons = violations(os.environ)
    print(json.dumps({'scope': 'web_delivery_build_configuration_only',
                      'status': 'BLOCKED' if reasons else 'CHECKED',
                      'reasons': reasons}, sort_keys=True))
    return 1 if reasons else 0


if __name__ == '__main__':
    sys.exit(main())
