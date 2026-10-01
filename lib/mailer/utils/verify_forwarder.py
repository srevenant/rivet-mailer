#!/usr/bin/python3
#
#
# goes alongside verify_email and processes it from postfix into elixir post
#
# bounce@simulator.amazonses.com
# success@simulator.amazonses.com
# ooto@simulator.amazonses.com
# complaint@simulator.amazonses.com
# suppressionlist@simulator.amazonses.com
#

import sys
import syslog
import urllib.request
import urllib.error

URL = "https://api.libreon.net/v1/api/verify"
SYSLOG = "mail"

def abort(msg):
    syslog.openlog(SYSLOG, syslog.LOG_PID | syslog.LOG_NDELAY, syslog.LOG_USER)
    syslog.syslog(syslog.LOG_ERR, msg)
    sys.exit(0)

def main():
    raw = sys.stdin.buffer.read()
    with open("/tmp/last-verified.debug", "wb") as debug:
        debug.write(raw)

    if not raw:
        abort("Could not read message body")

    request = urllib.request.Request(
        URL,
        data=raw,
        method="POST",
        headers={"Content-Type": "message/rfc822"}
    )

    try:
        with urllib.request.urlopen(request, timeout=5) as response:
            # 2xx or redirect = successfully handed off
            return 0

    except urllib.error.HTTPError as e:
        abort(f"Verification endpoint returned HTTP {e.code}")

    except urllib.error.URLError as e:
        abort(f"Verification endpoint unavailable: {e.reason}")

    except Exception as e:
        abort(f"Verification handoff failed: {type(e).__name__}: {e}")

if __name__ == "__main__":
    main()
