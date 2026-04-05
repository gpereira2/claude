---
name: regression-check
description: Monitors for potential regressions by correlating your merged PRs with recent Sentry errors (street and street-js projects) in Street CRM. Use when you want to check if your recent code changes caused production issues. Trigger with '/regression-check' or when investigating possible regressions from your PRs.
---

# Regression Monitor Skill

Correlate recently merged PRs with Sentry production errors to identify potential regressions.

## Quick Start

1. **Basic check** (PRs from last 7 days vs Sentry issues from last 6 hours):
   ```
   /regression-check
   ```

2. **Extended timeframes**: `/regression-check --days 14 --sentry-hours 24`
3. **Check another developer**: `/regression-check --author username`
4. **Higher confidence threshold**: `/regression-check --min-confidence 50`

## Configuration

| Argument | Default | Description |
|----------|---------|-------------|
| `--days` | 7 | Days back to search for merged PRs |
| `--sentry-hours` | 6 | Hours back to search for Sentry issues |
| `--author` | (current user) | GitHub username to analyse |
| `--min-confidence` | 25 | Minimum confidence % to report |

**Hardcoded values** (Street CRM specific):
- GitHub: `AgentSoftware/street`
- Sentry org: `agent-software`
- Sentry projects: `street`, `street-js`

## Workflow Phases

### Phase 1: Initialise

1. Parse arguments with defaults
2. Get authenticated username via `gh api user --jq '.login'`
3. Calculate date cutoff using **date-only** (midnight) boundaries: `$(date -v-{days}d +%Y-%m-%dT00:00:00Z)`
   - This ensures "7 days ago" means "all PRs merged on that calendar day or later", not time-bound

Display configuration being used before proceeding.

### Phase 2: Collect PR Data

**CRITICAL**: Use `gh pr list`, NOT `gh search prs` (the search API has unreliable indexing/date filtering).

Fetch PRs from **two sources in parallel** to capture both authored and assigned PRs:

```bash
# Source 1: PRs authored by the user
# cutoff_date is midnight-based (e.g. 2026-02-25T00:00:00Z) so all PRs from that day are included
gh pr list --repo AgentSoftware/street --author {username} --state merged --limit 100 \
  --json number,title,mergedAt,url \
  --jq '[.[] | select(.mergedAt >= "{cutoff_date}")]'

# Source 2: PRs assigned to the user (may be authored by others)
gh pr list --repo AgentSoftware/street --assignee {username} --state merged --limit 100 \
  --json number,title,mergedAt,url \
  --jq '[.[] | select(.mergedAt >= "{cutoff_date}")]'
```

**Deduplicate** by PR number after merging both lists.

For each PR, get changed files:
```bash
gh pr view {number} --repo AgentSoftware/street --json files --jq '[.files[].path]'
```

**Collect in parallel** where possible (multiple `gh pr view` calls).

Build file path index: `Map<filePath, PR[]>`

Parse ticket number from title (e.g., `[LMN-1234]` or `LMN-1234`).

**Edge cases**:
- No PRs found → Display message, skip to Phase 5
- API errors → Retry once, then continue with partial results

### Phase 3: Collect Sentry Data

Search **both projects in parallel** using `mcp__sentry__search_issues`:
- `projectSlugOrId: 'street'` — backend PHP errors
- `projectSlugOrId: 'street-js'` — frontend JS errors
- Query: `unresolved issues from the last {hours} hours`
- `organizationSlug: 'agent-software'`
- `limit: 100`

Merge results, tagging each with source project.

For issues with potential correlation, use `mcp__sentry__get_issue_details` to get stack traces.

**Path normalisation:**
```
# street (PHP backend)
/var/www/html/src/Domain/...  → src/Domain/...
/app/src/Domain/...           → src/Domain/...
Street\Domain\Core\Foo       → src/Domain/Core/Foo.php

# street-js (JavaScript frontend)
assets/resources/src/js/...   → resources/src/js/...
./vue/components/...          → resources/src/js/vue/components/...
```

**Edge cases**:
- No issues found → Display "All Clear" message
- Issues without stack traces → Still include, note missing data

### Phase 4: Correlation Analysis

Three-signal confidence scoring (0-100%).

#### Signal 1: File Path Matching (0-100%)

| Match Type | Score | Criteria |
|-----------|-------|----------|
| Exact | 100% | Stack trace file = PR changed file |
| Directory | 70% | Same directory as changed files |
| Related | 50% | Laravel relationships: Service↔Model, Controller↔Service, Job↔Event, Test↔Source |

#### Signal 2: Temporal Correlation (-20 to +40%)

| Timing | Score | Criteria |
|--------|-------|----------|
| Very suspicious | +40% | Issue first seen <2 hours after merge |
| Same day | +20% | Issue first seen <24 hours after merge |
| Pre-existing | -20% | Issue first seen BEFORE merge |

#### Signal 3: Semantic Analysis (0-65%)

| Signal | Score | Criteria |
|--------|-------|----------|
| Keyword overlap | 0-30% | Jaccard similarity of PR title vs issue title |
| Domain match | 0-20% | Same domain path (e.g., both in `Tenancies/`) |
| URL path match | 0-15% | Sentry issue culprit matches route from PR |

**Total**: Sum signals, cap at 0-100%.

**Risk levels:**
- CRITICAL: >80% confidence + high impact (>50 events or >10 users)
- HIGH: >60% confidence + moderate impact (>20 events)
- MEDIUM: >40% confidence + some impact (>5 events)
- LOW: >25% confidence

### Phase 5: Report Generation

Generate a markdown report with this structure:

```markdown
# Regression Check Report
Generated: {timestamp}
Author: {github_username}
Period: PRs merged in last {days} days, Sentry issues from last {hours} hours

## Summary
- **PRs Analysed**: {count}
- **Sentry Issues Found**: {count} (street: {backend}, street-js: {frontend})
- **Potential Regressions**: {count} ({critical} critical, {high} high, {medium} medium, {low} low)

---

## Critical Findings (Confidence >80%, High Impact)

### Issue: {issue_title}
**Project**: {project} | **Sentry**: [{shortId}]({url})
**Confidence**: {confidence}% | **Impact**: {events} events, {users} users
**First Seen**: {firstSeen} ({X} hours after PR merge)

**Linked PR**: [#{number}]({url}) - {title}
**Merged**: {mergedAt}
**Ticket**: [{ticket}](https://spectre.atlassian.net/browse/{ticket})

**Evidence**:
- File path match: {file} ({exact/directory/related})
- Timing: Issue appeared {X} hours after merge
- Semantic: {details}

**Immediate Action**:
1. Review PR changes in {file}
2. Check Sentry issue for reproduction steps
3. Consider rolling back PR #{number} if confirmed
4. If the PR has multiple commits, use `git bisect` to pinpoint the exact commit (see `references/bisect-guide.md`):
   ```bash
   git bisect start {merge_commit_sha} {merge_commit_sha}~{commit_count}
   git bisect run ./bisect-test.sh
   ```

---

## High Risk Findings (Confidence 60-80%)
{Similar format, less detail}

## Medium Risk Findings (Confidence 40-60%)
{Brief entries}

## Low Risk Findings (Confidence 25-40%)
{Brief list with links}

---

## All Clear (if no correlations)
No Sentry issues correlate with your recent PRs.

## All PRs Analysed
- [#{number}]({url}) - {title} | Merged: {date} | Correlated issues: {count}

## Methodology Notes
- Correlation does not prove causation
- Confidence scores are heuristic-based
- Pre-existing issues may still be related (incomplete fixes)
```

### Phase 6: Notifications

After generating the report, send notifications so the user knows the check is complete. This is essential for unattended/cron runs.

#### 6a. Discover Slack User ID

Look up the current user's Slack ID using `mcp__claude_ai_Slack__slack_search_users` with the GitHub username or a known name/email. Cache the result for the session.

If the search returns no results, skip the Slack DM and note it in the terminal output: "Could not find Slack user — Slack notification skipped."

#### 6b. Desktop Notification (terminal-notifier)

Send a macOS notification summarising the result:

**When regressions are found:**
```bash
terminal-notifier -title "Regression Check" \
  -subtitle "{critical + high} potential regressions" \
  -message "{critical} critical, {high} high, {medium} medium, {low} low — check Slack for details" \
  -sound "Basso" \
  -group "regression-check"
```

**When all clear:**
```bash
terminal-notifier -title "Regression Check" \
  -subtitle "All Clear ✓" \
  -message "No Sentry issues correlate with your recent PRs" \
  -sound "Glass" \
  -group "regression-check"
```

**When no PRs found:**
```bash
terminal-notifier -title "Regression Check" \
  -subtitle "No PRs Found" \
  -message "No merged PRs found in the last {days} days" \
  -sound "Glass" \
  -group "regression-check"
```

#### 6b. Slack DM

Send a condensed summary of the report to the user's Slack DM using `mcp__claude_ai_Slack__slack_send_message`.

- **Channel ID**: Use the Slack user ID discovered in step 6a (DM to self)
- **Message format**: Condensed Slack mrkdwn (not full markdown — Slack uses `*bold*` not `**bold**`)
- **Max length**: Keep under 4000 chars to stay well within Slack's 5000 char limit

**Message structure:**

```
*Regression Check Report* — {timestamp}
Author: {github_username} | PRs: last {days} days | Sentry: last {hours} hours

*Summary*
• PRs Analysed: {count}
• Sentry Issues: {count} (street: {backend}, street-js: {frontend})
• Potential Regressions: {count}

{If regressions found:}

*🔴 Critical ({count})*
• `{issue_title}` — {confidence}% confidence | {events} events, {users} users
  Sentry: {sentry_url}
  Linked PR: #{number} — {pr_title}
  Files: {matched_files}

*🟠 High ({count})*
• `{issue_title}` — {confidence}% | PR #{number}

*🟡 Medium ({count})*
• `{issue_title}` — {confidence}% | PR #{number}

*⚪ Low ({count})*
• `{issue_title}` — {confidence}% | PR #{number}

{If no regressions:}

✅ *All Clear* — No Sentry issues correlate with your recent PRs.
```

**Rules:**
- Only include sections that have findings (skip empty risk levels)
- For Critical/High: include Sentry link, PR link, matched files, and timing
- For Medium/Low: keep to one line each (title, confidence, PR number)
- If the message would exceed 4000 chars, truncate Low findings and add "_{N} more low-confidence findings — see terminal output_"

## Resources

- **`references/interpretation-guide.md`** — How to interpret confidence scores, impact metrics, false positive indicators, troubleshooting
- **`references/bisect-guide.md`** — How to use `git bisect run` to pinpoint the exact regression commit within a correlated PR