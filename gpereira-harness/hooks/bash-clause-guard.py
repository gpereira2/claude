#!/usr/bin/env python3
"""PreToolUse(Bash) clause guard — deny-only.

Decomposes compound commands (&&, ||, ;, |, &, newlines, $(), backticks) and
denies any clause matching a catastrophic pattern, so a dangerous clause can't
ride through inside an otherwise-approvable chain. Never auto-allows: clean
commands fall through to the normal permission flow (silent exit 0).
"""
import json
import re
import sys


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


def main():
    try:
        data = json.load(sys.stdin)
    except Exception:
        return 0
    cmd = (data.get("tool_input") or {}).get("command") or ""
    if not cmd:
        return 0
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
            return 0
    return 0


if __name__ == "__main__":
    sys.exit(main())
