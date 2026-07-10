## [Unreleased]

- Add explicit Claude, Codex, and generic provider targets backed by shared
  setup and maintenance artifacts.
- Add a `both` target for repositories used by Claude and Codex, including
  idempotently merged Claude hooks and Codex `AGENTS.md` recovery guidance.
- Add task-oriented provider setup, security, troubleshooting, concepts, and
  self-hosting documentation; remove identity-bearing preview URL examples.
- Replace global process matching with locked, project-owned PID/state
  reconciliation; credential changes restart the tunnel and removal stops it.
- Keep the chisel fingerprint independently pinned, strictly validate dynamic
  coordinates, verify downloaded chisel binaries, and remove shell re-parsing.
- Rely on Action Cable's exact same-origin protection instead of trusting every
  sibling preview origin.
- Detect the active database and JavaScript package manager, honor `APP_PORT`,
  and select the exact `.ruby-version`.

## [0.1.0] - 2026-07-06

- Initial release.
- Railtie that allows the tunnel's wildcard host and Action Cable origins in the
  configured environments (default `:development`), targeting `firstdraft.io` out
  of the box and configurable via `AgentVmTunnel.configure` / `AGENT_VM_TUNNEL_HOST`.
- `agent_vm_tunnel:install` generator that scaffolds `bin/agent-vm-tunnel`,
  `cloud-vm-setup.sh`, and merges Claude Code hooks into `.claude/settings.json`.
