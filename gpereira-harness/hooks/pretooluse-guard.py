#!/usr/bin/env python3
"""PreToolUse guard — single dispatcher for the three Python safety checks.

Merges the former bash-clause-guard.py, credential-file-guard.py and
secret-scan-guard.py into one interpreter spawn per tool call. The previous
wiring ran up to three python3 processes per call (a Write triggered secret
scan + credential guard; a Bash triggered clause guard + credential guard),
which at hundreds of tool calls per session is minutes of pure spawn overhead.

Routing is by input *shape*, not tool_name, preserving each original guard's
behaviour exactly:
  - `command` present        -> clause guard (deny-only) + credential CMD_RULES
  - path-ish keys present    -> credential PATH_RULES
  - `content`/`new_string`   -> secret scan

Each check keeps its original output contract: the clause guard emits the
hookSpecificOutput permissionDecision "deny" form; the credential and secret
checks emit {"decision": "block"}. Both are verified to be honoured on this
machine. permissionDecision "ask" is NOT used by default: with defaultMode
auto + skipAutoPermissionPrompt an "ask" verdict is auto-approved and blocks
nothing (verified 2026-07-24 — a Write containing a clean AWS-key match
completed with no prompt and no block). Set SECRET_SCAN_GUARD_MODE=ask to
restore the soft posture for the secret scan if your workflow writes fixtures
with fake key material often — but understand it may be a no-op in your session.

Known limitations (inherited): a Grep over a *directory* that incidentally
matches lines inside a credential file is not caught — a PreToolUse hook sees
inputs, never output. Key/certificate files are matched on file paths only,
not in shell commands: an unanchored match on command strings also caught
legitimate local-TLS tooling for no gain.

Never emits an explicit approval. This guard's matcher spans Bash, and an
explicit approve would short-circuit the permission check that would otherwise
prompt for an unrelated dangerous command. A guard must be able to say "no",
never "yes on everything else".
"""
import json
import os
import re
import sys

# ---------------------------------------------------------------- clause guard

def strip_heredocs(cmd):
    out, lines, skip_until = [], cmd.split("\n"), None
    for line in lines:
        if skip_until is not None:
            if line.strip() == skip_until:
                skip_until = None
            continue
        m = re.search(r"<<-?\s*['\"]?(\w+)['\"]?", line)
        if m:
            skip_until = m.group(1)
        out.append(line)
    return "\n".join(out)


def split_clauses(cmd):
    clauses, cur, extras = [], "", []
    sq = dq = False
    depth = 0
    i, n = 0, len(cmd)
    while i < n:
        c = cmd[i]
        nxt = cmd[i + 1] if i + 1 < n else ""
        if c == "\\" and not sq:
            cur += cmd[i:i + 2]
            i += 2
            continue
        if c == "'" and not dq:
            sq = not sq
        elif c == '"' and not sq:
            dq = not dq
        elif not sq and not dq:
            if c == "$" and nxt == "(":
                depth += 1
                i += 2
                start = i
                inner = 1
                while i < n and inner:
                    if cmd[i] == "(":
                        inner += 1
                    elif cmd[i] == ")":
                        inner -= 1
                    i += 1
                extras.append(cmd[start:i - 1])
                depth -= 1
                continue
            if c == "`":
                end = cmd.find("`", i + 1)
                if end == -1:
                    end = n
                extras.append(cmd[i + 1:end])
                i = end + 1
                continue
            if depth == 0 and (c in ";\n" or (c == "&" and nxt != ">") or c == "|"):
                if cur.strip():
                    clauses.append(cur.strip())
                cur = ""
                while i < n and cmd[i] in "&|;\n ":
                    i += 1
                continue
        cur += c
        i += 1
    if cur.strip():
        clauses.append(cur.strip())
    for e in extras:
        clauses.extend(split_clauses(e))
    return clauses


def normalize(clause):
    clause = re.sub(r"^(\w+=\S*\s+)+", "", clause)
    clause = re.sub(r"\s+\d*>>?&?\s*\S+", " ", clause)
    clause = re.sub(r"\s+<\s*\S+", " ", clause)
    return clause.strip()


DENY = [
    (r"^git\s+push\b.*(\s--force(-with-lease)?\b|\s-[a-zA-Z]*f\b|\s\+\S+)",
     "force push is forbidden — run it manually if truly intended"),
    (r"^git\s+reset\s+--hard\b",
     "git reset --hard discards work — forbidden from agent sessions"),
    (r"^git\s+clean\s+-\w*f",
     "git clean -f deletes untracked files — forbidden from agent sessions"),
    (r"(^|\s)(mysql|psql)\b.*\b(drop\s+(database|table)|truncate\s)\w*",
     "raw destructive SQL from a shell is forbidden — hand the SQL to the user"),
    (r"artisan\s+(migrate:fresh|migrate:refresh|db:wipe)\b",
     "drops tables and destroys database data — forbidden from agent sessions"),
    # Ported from the live user-level config 2026-08-18, where it had run in
    # settings.json as three greps over the whole command string. Rewritten as one
    # clause-anchored regex because this guard splits clauses and strips heredocs
    # first — the whole-string form false-positives on any command that merely
    # quotes the text (it blocked a heredoc test fixture during the port).
    # `down` is load-bearing: -v on `docker run` is a volume *mount*, not a delete.
    # Covers `docker compose` and legacy `docker-compose`, flags before the
    # subcommand (-f foo.yml), and bundled short flags (-tv). Deliberately not
    # covered: -v preceding `down`, which is not valid for this subcommand.
    # Known imprecision: a word-bounded "down" inside a filename plus a later -v
    # denies — accepted, since the failure direction is a clear block, not a
    # silent volume delete.
    (r"^docker(-compose|\s+compose)\b.*\bdown\b.*(\s-\w*v\b|\s--volumes\b)",
     "compose down with volumes deletes named volumes (database data) — drop the flag, or run it manually if truly intended"),
]


def rm_is_catastrophic(clause):
    toks = clause.split()
    if not toks or toks[0] != "rm":
        return False
    flags = "".join(t[1:] for t in toks[1:] if t.startswith("-"))
    if "r" not in flags.lower():
        return False
    targets = [t for t in toks[1:] if not t.startswith("-")]
    for t in targets:
        t = t.strip("'\"")
        norm = t.rstrip("/") or "/"
        if norm in ("/", "~", "*", ".", "..", "$HOME", "~/*", "/*", "$HOME/*"):
            return True
        if norm == ".git" or norm.endswith("/.git"):
            return True
        if re.fullmatch(r"/\w+", norm):  # top-level absolute dir like /etc
            return True
    return False


def check_bash_clauses(cmd):
    for raw in split_clauses(strip_heredocs(cmd)):
        clause = normalize(raw)
        if rm_is_catastrophic(clause):
            reason = f"recursive rm against a catastrophic target — blocked clause: `{clause}`"
        else:
            reason = next((why for pat, why in DENY if re.search(pat, clause, re.IGNORECASE)), None)
            if reason:
                reason = f"{reason} — blocked clause: `{clause}`"
        if reason:
            print(json.dumps({"hookSpecificOutput": {
                "hookEventName": "PreToolUse",
                "permissionDecision": "deny",
                "permissionDecisionReason": reason,
            }}))
            return True
    return False


# ---------------------------------------------------------- credential files

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


def block_credential(what, how):
    print(json.dumps({
        "decision": "block",
        "reason": (
            f"{how} access to {what} is blocked to protect credentials. "
            "Describe the file's shape or location instead of reading its contents."
        ),
    }))
    return True


def check_credential_paths(ti):
    for key in ("file_path", "path", "notebook_path", "glob", "pattern"):
        value = ti.get(key)
        if not isinstance(value, str) or not value:
            continue
        cleaned = EXAMPLE_SUFFIX.sub("", value)
        for what, pat in PATH_RULES:
            if pat.search(cleaned):
                return block_credential(what, "File")
    return False


def check_credential_command(cmd):
    cleaned = EXAMPLE_SUFFIX.sub("", cmd)
    for what, pat in CMD_RULES:
        if pat.search(cleaned):
            return block_credential(what, "Shell")
    return False


# ----------------------------------------------------------------- secret scan

SECRET_PATTERNS = [
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


def check_secrets(ti):
    content = ti.get("content") or ti.get("new_string") or ""
    if not content:
        return False
    findings = []
    for name, pat in SECRET_PATTERNS:
        for m in re.finditer(pat, content, re.IGNORECASE if "assignment" in name or "string" in name else 0):
            line = content.count("\n", 0, m.start()) + 1
            findings.append(f"line {line}: {name}")
            break  # one report per pattern type is enough
    if not findings:
        return False
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
    return True


# ------------------------------------------------------------------ dispatcher

def main():
    try:
        data = json.load(sys.stdin)
    except Exception:
        return 0
    ti = data.get("tool_input") or {}

    cmd = ti.get("command")
    if isinstance(cmd, str) and cmd:
        if check_bash_clauses(cmd):
            return 0
        if check_credential_command(cmd):
            return 0

    if check_credential_paths(ti):
        return 0

    if check_secrets(ti):
        return 0

    # Silent exit when nothing matched — never an explicit approve (see module docstring).
    return 0


if __name__ == "__main__":
    sys.exit(main())
