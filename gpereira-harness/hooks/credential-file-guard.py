#!/usr/bin/env python3
"""PreToolUse guard: block reads of credential files.

Extends the inline .env / auth.json block in settings.json to the rest of the
credential-file set (.npmrc, netrc, *.pem) and to tools the inline matchers
miss (Grep/Glob when they explicitly target a credential file).

Emits the {"decision": "block"} contract, which is verified to be honoured on
this machine. permissionDecision "ask" is NOT used: it is inert here because
defaultMode is auto with skipAutoPermissionPrompt set, so an "ask" verdict is
auto-approved and blocks nothing.

Known limitations: a Grep over a *directory* that incidentally matches lines
inside a credential file is not caught — a PreToolUse hook sees inputs, never
output, so it cannot redact what a search prints. And key/certificate files are
matched on file paths only, not in shell commands: the vector here is reading a
credential file, while an unanchored match on command strings also caught
legitimate local-TLS tooling for no gain.
"""
import json
import re
import sys

EXAMPLE_SUFFIX = re.compile(r"\.env\.(example|sample|template|dist)\b")

PATH_RULES = [
    ("auth.json", re.compile(r"(^|/)auth\.json$")),
    (".env file", re.compile(r"(^|/)\.env($|\.)")),
    (".npmrc", re.compile(r"(^|/)\.npmrc$")),
    ("netrc", re.compile(r"(^|/)_?\.?netrc$")),
    ("PEM key/certificate", re.compile(r"\.pem$")),
]

CMD_RULES = [
    ("auth.json", re.compile(r"(^|[\s/=\"'])auth\.json($|[\s\"'])")),
    (".env file", re.compile(r"(^|[\s/=\"'])\.env($|[\s.\"'])")),
    (".npmrc", re.compile(r"(^|[\s/=\"'])\.npmrc($|[\s\"'])")),
    ("netrc", re.compile(r"(^|[\s/=\"'])_?\.?netrc($|[\s\"'])")),
]


def block(what, how):
    print(json.dumps({
        "decision": "block",
        "reason": (
            f"{how} access to {what} is blocked to protect credentials. "
            "Describe the file's shape or location instead of reading its contents."
        ),
    }))
    return 0


def main():
    try:
        data = json.load(sys.stdin)
    except Exception:
        return 0
    ti = data.get("tool_input") or {}

    candidates = [ti.get(k) for k in ("file_path", "path", "notebook_path", "glob", "pattern")]
    for value in candidates:
        if not isinstance(value, str) or not value:
            continue
        cleaned = EXAMPLE_SUFFIX.sub("", value)
        for what, pat in PATH_RULES:
            if pat.search(cleaned):
                return block(what, "File")

    cmd = ti.get("command")
    if isinstance(cmd, str) and cmd:
        cleaned = EXAMPLE_SUFFIX.sub("", cmd)
        for what, pat in CMD_RULES:
            if pat.search(cleaned):
                return block(what, "Shell")

    # Exit silently when nothing matched. Never emit {"decision": "approve"}:
    # this hook's matcher spans Bash, and an explicit approval short-circuits the
    # permission check that would otherwise prompt for an unrelated dangerous
    # command. A guard must be able to say "no", never "yes on everything else".
    return 0


if __name__ == "__main__":
    sys.exit(main())
