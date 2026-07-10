---
layout: default
title: Documentation
---

# Agent VM Tunnel documentation

Agent VM Tunnel gives an application inside an outbound-only development
environment a stable browser-accessible URL. It currently supports Rails apps
in Codex Cloud, Claude cloud environments, and compatible Linux sandboxes.

## Choose a path

- **I want a preview:** follow the [quickstart](quickstart.md), then open the
  setup guide for [Codex Cloud](providers/codex-cloud.md) or
  [Claude](providers/claude-code.md).
- **I want to understand it first:** read [how it works](concepts.md) and the
  [security model](security.md).
- **Something failed:** start with [troubleshooting](troubleshooting.md).
- **I operate my own tunnel:** read [self-hosting](self-hosting.md), then use
  the control-plane repository's deployment runbook.

## The two values that matter

After accepting an invite at <https://firstdraft.io>, the dashboard gives each
preview:

1. an opaque URL such as `https://p-a1b2c3d4e5f60718293a.firstdraft.io`; and
2. a credential such as `AGENT_VM_TUNNEL=42:<random-password>`.

The URL is safe to share when you want someone to see the app. The credential
is not: it authorizes a process to attach to that preview's private reverse
port. Store it only in the cloud provider's environment-variable UI.

## Supported provider behavior

The Rails integration and tunnel protocol are provider-neutral. Only lifecycle
automation differs:

| Environment | Initial setup | Wake-up behavior |
|---|---|---|
| Codex Cloud | Codex environment setup script | Codex maintenance script |
| Claude cloud environment | Claude environment setup script | Repository hooks on session start and prompts |
| Generic Linux VM | Run the setup script yourself | Run `bin/agent-vm-tunnel ensure` after resume |

Provider setup screens and network policies are different. Do not copy fields
from one provider guide into the other.
