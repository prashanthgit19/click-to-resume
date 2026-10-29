# Privacy

DevSessions is a local-only macOS utility.

- It reads session metadata from OpenCode, Claude Code, Codex, Pi, and Oh My Pi on this Mac.
- It writes session metadata to the DevSessions App Group cache so the widget can display it.
- It does not send session data, usage data, or telemetry to any server.
- It does not use an account, cloud service, or AI model.
- Session titles may contain sensitive prompt text. They are stored locally in the App Group container with owner-only permissions and are not logged by DevSessions.

Resuming a session opens the selected terminal and runs that agent’s own resume command. The agent may then use its own network access, credentials, and data policies.
