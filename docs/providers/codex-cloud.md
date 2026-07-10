---
layout: default
title: Codex Cloud
---

# Set up Codex Cloud

Codex Cloud uses its own environment form. It does not use Claude hooks or the
Claude environment setup wrapper.

Before continuing, complete the repository steps in the
[quickstart](../quickstart.md) with `--provider=codex` or `--provider=both`, and
push those generated files to the branch Codex will check out.

If a Claude environment for the same repository may run concurrently, create a
separate dashboard preview for Codex. The `both` target installs both providers'
repository integration; it does not make one reverse port accept two apps.

## 1. Open the environment

Open [Codex settings → Environments](https://chatgpt.com/codex/settings/environments)
and create or edit the environment attached to this GitHub repository.

Configure these fields:

| Codex field | Value |
|---|---|
| Environment variables | `AGENT_VM_TUNNEL=<slot>:<password>` from the matching dashboard preview |
| Setup script | `bash cloud-vm-setup.sh` |
| Maintenance script | `bin/agent-vm-tunnel ensure` |
| Agent internet access | **On** |
| Domain allowlist | `firstdraft.io` and `tunnel.firstdraft.io` |
| Allowed HTTP methods | `GET`, `HEAD`, and `OPTIONS` are sufficient for coordinates and the WebSocket handshake |

Use an **environment variable**, not a Codex **secret**, for
`AGENT_VM_TUNNEL`. Codex environment variables remain available throughout the
task. Codex secrets are deliberately removed after the setup phase, while the
connector must be able to reconcile during maintenance and the agent phase.

The setup script runs with internet access. Restrict agent-phase access to the
two tunnel domains above. If the tunnel cannot complete its WebSocket upgrade,
temporarily select the unrestricted domain preset to distinguish a Codex
allowlist problem from an application problem, then narrow it again.

## 2. Understand the image choice

Codex Cloud currently runs OpenAI's `universal` container image. The environment
screen can pin selected package versions, and the setup script can install
additional dependencies. It does not currently document an option to upload a
custom Docker image or build the repository's Dockerfile.

The published `openai/codex-universal` Dockerfile is useful for inspecting or
testing the base environment locally; it is not a custom-image input for a
Codex Cloud environment.

Agent VM Tunnel therefore needs `cloud-vm-setup.sh`. The script selects the
exact Ruby from `.ruby-version`, installs application dependencies, prepares
the database, and installs the pinned chisel client into the project tree.

## 3. Lifecycle behavior

Codex runs setup when it prepares a new container and the maintenance script
when it resumes a cached container. Codex Cloud does not currently document a
repository hook that runs before every prompt.

The generator therefore also adds a small section to `AGENTS.md`. It tells
Codex to run `ensure` before preview-dependent work and to use `status` for
diagnostics. This is recovery guidance, while the environment's setup and
maintenance fields remain the deterministic lifecycle integration.

## 4. Save and start a task

Save the environment, then submit a task on the repository. Codex checks out
the selected branch, prepares or resumes the cached container, and invokes the
configured lifecycle script.

Ask Codex to verify the preview, or run this in its terminal:

```bash
bin/agent-vm-tunnel ensure
bin/agent-vm-tunnel status
```

Open the opaque preview URL from <https://firstdraft.io>. Do not derive a URL
from your GitHub login or repository name.

## 5. When configuration changes

Codex invalidates its container cache when environment fields change. If you
change `.ruby-version`, database packages, or the generated setup script and a
cached environment behaves inconsistently, use **Reset cache** on the Codex
environment page and start a new task.

## Official Codex references

- [Cloud environments](https://learn.chatgpt.com/docs/environments/cloud-environment)
- [Agent internet access](https://learn.chatgpt.com/docs/cloud/internet-access)
