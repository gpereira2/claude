#!/usr/bin/env python3
"""PreToolUse(Write|Edit) secret scanner.

Scans outgoing content (Write.content / Edit.new_string) for credential
patterns before they land on disk. Verdict is "ask" (not deny) because test
fixtures legitimately contain fake credentials — the user confirms or rejects
with the finding named. Silent exit when clean.
"""
import json
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
    print(json.dumps({"hookSpecificOutput": {
        "hookEventName": "PreToolUse",
        "permissionDecision": "ask",
        "permissionDecisionReason": (
            f"Potential secrets in {fp}: " + "; ".join(findings)
            + ". Confirm only if these are fake/test values."
        ),
    }}))
    return 0


if __name__ == "__main__":
    sys.exit(main())
