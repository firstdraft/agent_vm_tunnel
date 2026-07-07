## [Unreleased]

## [0.1.0] - 2026-07-06

- Initial release.
- Railtie that allows the tunnel's wildcard host and Action Cable origins in the
  configured environments (default `:development`), targeting `firstdraft.io` out
  of the box and configurable via `AgentVmTunnel.configure` / `AGENT_VM_TUNNEL_HOST`.
- `agent_vm_tunnel:install` generator that scaffolds `bin/preview`,
  `cloud-vm-setup.sh`, and merges Claude Code hooks into `.claude/settings.json`.
