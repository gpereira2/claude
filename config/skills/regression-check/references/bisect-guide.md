# Git Bisect Guide — Pinpointing Regression Commits

When the regression check identifies a high-confidence correlation with a multi-commit PR, use `git bisect run` to automatically find the exact commit that introduced the bug.

## When to Use

- A CRITICAL or HIGH finding points to a PR with **multiple commits**
- You need to narrow down which specific change caused the issue
- Manual review of the full PR diff is too large to pinpoint the cause

Skip bisect if the PR is a single commit — you already know the culprit.

## Workflow

### 1. Identify the commit range

From the regression report, note the **merge commit SHA** and the **number of commits** in the PR:

```bash
# Get the merge commit and its parent commits
gh pr view {number} --repo AgentSoftware/street --json mergeCommit,commits \
  --jq '{merge: .mergeCommit.oid, count: (.commits | length)}'
```

### 2. Create a reproducer

Write a minimal test or script that **fails when the bug is present** and **passes when it's not**.

**Backend (PHPUnit)** — create a test file e.g. `tests/bisect-regression.php`:
```php
<?php
// Minimal reproduction of the Sentry error
// This test should FAIL on the bad commit and PASS on the good commit
```

**Frontend (Jest)** — create a test file e.g. `tests/bisect-regression.test.js`:
```js
// Minimal reproduction of the JS error
// This test should FAIL on the bad commit and PASS on the good commit
```

### 3. Write the bisect test script

Create `bisect-test.sh` in the project root:

**For backend regressions (error appeared — false positive pattern):**
```bash
#!/bin/bash
# Bisect script: exits 0 (good) when bug is absent, 1 (bad) when bug is present

# Reinstall dependencies (commits may change composer.lock)
docker compose exec app composer install --no-interaction --quiet 2>/dev/null

# Run the reproducer test — if it PASSES, the bug is present (bad commit)
# Invert exit code: test passing = bug exists = bad
docker compose exec app php artisan test tests/bisect-regression.php --stop-on-failure 2>&1 | grep -q "FAIL"
```

**For backend regressions (error disappeared — false negative pattern):**
```bash
#!/bin/bash
# Bisect script: exits 0 (good) when expected behaviour works, 1 (bad) when it doesn't

docker compose exec app composer install --no-interaction --quiet 2>/dev/null

# Run the reproducer — if it FAILS, the regression is present (bad commit)
docker compose exec app php artisan test tests/bisect-regression.php --stop-on-failure
```

**For frontend regressions:**
```bash
#!/bin/bash
npm install --silent 2>/dev/null
npm test -- tests/bisect-regression.test.js --silent
```

Make it executable:
```bash
chmod +x bisect-test.sh
```

### 4. Run the bisect

```bash
# Start bisect with known bad (merge commit) and good (commit before PR)
git bisect start
git bisect bad {merge_commit_sha}
git bisect good {merge_commit_sha}~{commit_count}

# Let git automatically find the first bad commit
git bisect run ./bisect-test.sh
```

Git will output the **first bad commit** with its full details (SHA, author, message, diff stats).

### 5. Clean up

```bash
git bisect reset
rm bisect-test.sh tests/bisect-regression.php  # or .test.js
```

## Exit Code Conventions

| Exit Code | Meaning to `git bisect` |
|-----------|------------------------|
| 0 | **Good** — bug not present at this commit |
| 1-124, 126-127 | **Bad** — bug is present at this commit |
| 125 | **Skip** — this commit can't be tested (e.g. broken build) |
| 128+ | **Abort** — bisect stops entirely |

Use exit code 125 when a commit fails to build or dependencies can't install — git will skip it and try an adjacent commit instead.

### Handling untestable commits

If some commits in the range break the build, wrap your script:

```bash
#!/bin/bash
docker compose exec app composer install --no-interaction --quiet 2>/dev/null
if [ $? -ne 0 ]; then
    exit 125  # Skip this commit — can't install dependencies
fi

docker compose exec app php artisan test tests/bisect-regression.php --stop-on-failure
```

## Tips

- **Keep the reproducer minimal** — faster execution = faster bisect (binary search across N commits takes log2(N) steps)
- **Commit the reproducer before starting** — stash or commit on a separate branch so it persists across checkout
- **Docker state**: if the bisect crosses schema changes, you may need to add `php artisan migrate` to the script
- **Parallel work**: bisect checks out commits in the working tree, so use a git worktree if you need to keep working:
  ```bash
  git worktree add ../street-bisect HEAD
  cd ../street-bisect
  # Run bisect here
  ```