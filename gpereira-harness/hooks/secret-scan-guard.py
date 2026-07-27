#!/usr/bin/env python3
"""PreToolUse(Write|Edit) secret scanner.

Scans outgoing content (Write.content / Edit.new_string) for credential
patterns before they land on disk. Silent exit when clean.

Verdict defaults to "deny", deliberately. An earlier version returned "ask" on
the theory that the user would confirm fixtures containing fake credentials —
but "ask" is not a reliable control: a session running with auto-approval
(permission mode `auto` / a skip-prompt setting) resolves it to approve with no
prompt shown, so the guard passes silently and the installer believes they are
covered when they are not. Verified 2026-07-24: a Write containing a clean
match for the AWS pattern below completed with no prompt and no block.

Set SECRET_SCAN_GUARD_MODE=ask to restore the soft posture if your workflow
writes fixtures with fake key material often enough that denial is the wrong
default — but understand it may be a no-op in your session.
"""
import json
import os
import re
import sys

PATTERNS = [
    ("AWS access key", r"AKIA[0-9A-Z]{16}"),
    ("AWS secret key assignment", r"aws_secret_access_key\s*[:=]\s*[\"']?[A-Za-z0-9/+=]{40}"),
    ("GitHub token", r"(ghp|gho|ghu|ghs|ghr)_[A-Za-z0-9_]{36,}"),
    ("GitHub fine-grained PAT", r"github_pat_[A-Za-z0-9_]{22,}"),
    ("Private key block", r"-----BEGIN (RSA|EC|OPENSSH|PGP|DSA)? ?PRIVATE KEY-----"),
    ("Slack token", r"xox[bpors]-[0-9a-zA-Z-]{10,}"),
    ("Stripe live secret key", r"sk_live_[A-Za-z0-9]{20,}"),
    ("Anthropic API key", r"sk-ant-[A-Za-z0-9_-]{20,}"),
    ("SendGrid API key", r"SG\.[A-Za-z0-9_-]{22}\.[A-Za-z0-9_-]{43}"),
    ("Connection string with password", r"(postgres|postgresql|mysql|mongodb(\+srv)?|redis)://[^:/\s]+:[^@\s]+@"),
    ("JWT", r"eyJ[A-Za-z0-9_-]{10,}\.eyJ[A-Za-z0-9_-]{10,}\.[A-Za-z0-9_-]{10,}"),
    ("Generic api key assignment", r"api[_-]?key\s*[:=]\s*[\"'][A-Za-z0-9]{20,}[\"']"),
]


def main():
    try:
        data = json.load(sys.stdin)
    except Exception:
        return 0
    ti = data.get("tool_input") or {}
    content = ti.get("content") or ti.get("new_string") or ""
    if not content:
        return 0
    findings = []
    for name, pat in PATTERNS:
        for m in re.finditer(pat, content, re.IGNORECASE if "assignment" in name or "string" in name else 0):
            line = content.count("\n", 0, m.start()) + 1
            findings.append(f"line {line}: {name}")
            break  # one report per pattern type is enough
    if not findings:
        return 0
    fp = ti.get("file_path") or "content"
    reason = (
        f"Potential secrets in {fp}: " + "; ".join(findings)
        + ". Write them outside the guarded tools, or set "
          "SECRET_SCAN_GUARD_MODE=ask if these are fixtures."
    )
    if os.environ.get("SECRET_SCAN_GUARD_MODE") == "ask":
        print(json.dumps({"hookSpecificOutput": {
            "hookEventName": "PreToolUse",
            "permissionDecision": "ask",
            "permissionDecisionReason": reason,
        }}))
    else:
        print(json.dumps({"decision": "block", "reason": reason}))
    return 0


if __name__ == "__main__":
    sys.exit(main())
