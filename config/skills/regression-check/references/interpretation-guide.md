# Regression Check — Interpretation Guide

## Confidence Scores

**90-100%** (Near certain):
- Exact file path match + appeared immediately after merge + semantic match
- Action: Investigate immediately

**70-89%** (Very likely):
- Strong file correlation + good timing
- Action: High priority investigation

**50-69%** (Possible):
- Related files or moderate timing
- Action: Review but not urgent

**25-49%** (Weak correlation):
- Semantic match or loose timing
- Action: Monitor, investigate if issue escalates

**<25%** (No correlation):
- Filtered out by default (use `--min-confidence 0` to see all)

## Impact Metrics

**Event Count**:
- <5: Low | 5-20: Moderate | 20-50: High | >50: Critical

**Affected Users**:
- <5: Limited | 5-10: Moderate | >10: Wide

## False Positive Indicators

**Be cautious when**:
- Confidence driven only by semantic match (no file correlation)
- Issue existed before PR merge (negative temporal score)
- Issue in completely different domain
- Stack trace mostly framework code (not `inApp: true` frames)

**Trust the correlation when**:
- High file path match (exact or directory)
- Issue appeared <2 hours after merge
- Multiple signals align (files + timing + semantics)

## Troubleshooting

### "No PRs found"
- Extend timeframe: `--days 14`
- Check another developer: `--author other-username`

### "Failed to fetch Sentry issues"
- Verify Sentry MCP is configured
- Check org is `agent-software`
- Retry (transient API errors)

### "Many low-confidence matches"
- Increase threshold: `--min-confidence 50`
- Focus on issues with file path matches

### "Issue existed before my PR"
- Your PR may have made the issue more frequent
- Your fix may be incomplete
- Could be coincidental (true false positive)
- Review stack trace to check if your changes are present