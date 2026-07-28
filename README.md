# CodexTokenWatch

An independently implemented macOS 13+ menu-bar app for inspecting local Codex usage. It reads `~/.codex/sessions` only and never uploads session content or usage data.

## Features

- Five-hour and weekly allowance cards when rate-limit data exists in local logs
- Green/yellow/red menu-bar status lights based on remaining allowance
- Today, this week, and all-local token totals
- A 14-day activity chart
- Uncached input, cached input, and output composition
- A local equivalent-credit estimate
- Manual refresh, five-minute background refresh, launch at login, and quit actions
- Duplicate usage-event detection for copied or forked session history

## Build and run

```sh
swift run CodexTokenWatch
```

To build an optimized binary:

```sh
swift build -c release
```

The scanner uses incremental `last_token_usage` events and rate-limit windows from Codex JSONL logs. Values are estimates: local files may be incomplete and Codex may change its log format. Official Codex usage remains authoritative.

## Privacy

- No network calls
- No API keys
- No log contents leave the Mac
- Only token counters, timestamps, and rate-limit fields are aggregated in memory
