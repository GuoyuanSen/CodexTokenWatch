# CodexTokenWatch

A standalone macOS menu-bar app for estimating local Codex token activity. It reads local JSON/JSONL session files only; it never sends logs or usage data anywhere.

## What it shows

- Today's, this week's, and all-time token totals
- A breakdown of input, cached input, and output tokens
- A compact menu-bar indicator with the current week's activity
- A refresh action and a launch-at-login option

## Build and run

```sh
swift run CodexTokenWatch
```

To build an optimized binary:

```sh
swift build -c release
```

The scanner looks in `~/.codex` and accepts JSON or JSONL records containing common token fields such as `input_tokens`, `cached_input_tokens`, and `output_tokens`. This is an estimate: Codex may change its local log format, and official usage pages remain authoritative.
