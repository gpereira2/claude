import json, os, subprocess, sys

GUARD = os.path.join(os.path.dirname(os.path.abspath(__file__)), "pretooluse-guard.py")
DOT = "." + "env"
PEM = "." + "pem"
KEY_HEADER = "-----BEGIN RSA " + "PRIVATE " + "KEY-----"

# expect True = the guard must block/deny; False = the guard must stay silent.
CASES = [
    # credential file paths
    ("read auth.json", {"file_path": "/repo/auth.json"}, True),
    ("read " + DOT, {"file_path": "/repo/" + DOT}, True),
    ("read " + DOT + ".local", {"file_path": "/repo/" + DOT + ".local"}, True),
    ("read " + DOT + ".example", {"file_path": "/repo/" + DOT + ".example"}, False),
    ("read .npmrc", {"file_path": "/tmp/x/.npmrc"}, True),
    ("read .netrc", {"file_path": "/tmp/x/.netrc"}, True),
    ("read _netrc", {"file_path": "/tmp/x/_netrc"}, True),
    ("read key" + PEM, {"file_path": "/certs/key" + PEM}, True),
    ("read normal file", {"file_path": "/repo/src/App.php"}, False),
    ("read authors.json", {"file_path": "/repo/authors.json"}, False),
    ("read environment.php", {"file_path": "/repo/environment.php"}, False),
    ("grep path .npmrc", {"pattern": "token", "path": "/tmp/x/.npmrc"}, True),
    ("grep path dir", {"pattern": "token", "path": "/tmp/x/project"}, False),
    # credential files via shell commands
    ("bash cat .npmrc", {"command": "cat ~/.npmrc"}, True),
    ("bash cat auth.json", {"command": "cat auth.json"}, True),
    ("bash cat " + DOT, {"command": "cat " + DOT}, True),
    ("bash cat " + DOT + ".example", {"command": "cat " + DOT + ".example"}, False),
    ("bash harmless", {"command": "git status"}, False),
    ("bash npm install", {"command": "npm install --no-audit"}, False),
    # regression guards: local-TLS tooling must stay runnable
    ("bash write public cert", {"command": "openssl s_client -connect x:443 > /tmp/chain" + PEM}, False),
    ("bash refresh certs script", {"command": "bash docker/php/certs/refresh.sh"}, False),
    ("bash generate-certs", {"command": "bash scripts/makefile/generate-certs.sh"}, False),
    ("bash make certs", {"command": "make certs"}, False),
    ("bash curl with cert flag", {"command": "curl --cacert /etc/ssl/ca" + PEM + " https://example.test"}, False),
    # clause guard: catastrophic clauses can't ride inside approvable chains
    ("bash rm -rf home chained", {"command": "x && rm -rf ~"}, True),
    ("bash force push", {"command": "git push --force origin main"}, True),
    ("bash reset hard", {"command": "git reset --hard HEAD~3"}, True),
    ("bash compose down -v", {"command": "docker compose down -v"}, True),
    ("bash compose down plain", {"command": "docker compose down"}, False),
    ("bash migrate:fresh", {"command": "php artisan migrate:fresh --seed"}, True),
    ("bash safe ls", {"command": "ls -la"}, False),
    # secret scan on outgoing content
    ("write aws key", {"file_path": "/tmp/x", "content": "AKIA" + "0" * 16}, True),
    ("write private key block", {"file_path": "/tmp/x", "content": KEY_HEADER}, True),
    ("edit clean content", {"file_path": "/tmp/x", "new_string": "return response()->json($data);"}, False),
    ("write clean content", {"file_path": "/tmp/x", "content": "hello world"}, False),
]

fails = 0
for label, ti, expect in CASES:
    p = subprocess.run([sys.executable, GUARD], input=json.dumps({"tool_input": ti}),
                       capture_output=True, text=True)
    out = json.loads(p.stdout or "{}")
    got = (out.get("decision") == "block"
           or (out.get("hookSpecificOutput") or {}).get("permissionDecision") == "deny")
    ok = got == expect
    if not ok:
        fails += 1
    print(("PASS " if ok else "FAIL ") + label + " -> " + (p.stdout.strip() or "silent"))

print("\n" + ("ALL PASS (" + str(len(CASES)) + " cases)" if fails == 0 else str(fails) + " FAILURES"))
sys.exit(1 if fails else 0)
