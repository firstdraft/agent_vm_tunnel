---
layout: default
title: Quickstart
---

# Quickstart

This guide covers the shared work in the Rails repository. Finish with the
provider-specific setup page for the environment you use.

## 1. Claim a preview

Open the invite link from your workshop organizer, sign in to
<https://firstdraft.io> with GitHub, and create a preview for this application.
Use the app name only to distinguish previews in the dashboard; it is not
included in the public hostname.

Keep the dashboard open. You will need:

- the opaque `https://p-<random>.firstdraft.io` URL; and
- the `AGENT_VM_TUNNEL=<slot>:<password>` line.

## 2. Install the connector

Add the gem:

```ruby
# Gemfile
gem "agent_vm_tunnel", github: "firstdraft/agent_vm_tunnel"
```

Install it and generate files for one provider or both:

```bash
bundle install

# Codex Cloud
bin/rails generate agent_vm_tunnel:install --provider=codex

# OR: Claude cloud environment
bin/rails generate agent_vm_tunnel:install --provider=claude

# OR: use the same repository in both services
bin/rails generate agent_vm_tunnel:install --provider=both
```

`both` installs both lifecycle integrations; it does not multiplex two running
containers into one preview. If the Codex and Claude environments may be active
at the same time, create two dashboard previews (for example, `blog-codex` and
`blog-claude`) and give each environment its own credential and URL. One
credential is acceptable only when the environments are used alternately.

Commit the generated files. Do not put the dashboard credential in any of
them.

| Generated path | Purpose |
|---|---|
| `config/agent_vm_tunnel.json` | Pinned host, server fingerprint, and provider |
| `cloud-vm-setup.sh` | Dependencies, database preparation, and environment setup |
| `bin/agent-vm-tunnel` | Idempotent app and tunnel supervisor |
| `.claude/settings.json` | Claude lifecycle hooks; generated for `claude` and `both` |
| `AGENTS.md` | Codex recovery guidance; generated for `codex` and `both` without replacing existing instructions |

## 3. Configure the cloud environment

The screens are not equivalent. Follow exactly one guide:

- [Codex Cloud](providers/codex-cloud.md)
- [Claude cloud environment](providers/claude-code.md)

## 4. Verify the preview

Inside the cloud environment, run:

```bash
bin/agent-vm-tunnel ensure
bin/agent-vm-tunnel status
```

The status output should show both the app and tunnel as running. Open the
opaque URL from the dashboard in your browser. If it does not load, use the
[troubleshooting guide](troubleshooting.md) before regenerating or changing
credentials.

## Everyday operation

Normally there is nothing to start manually. Provider lifecycle automation
runs the same idempotent `ensure` command after the environment wakes.

Useful commands:

```bash
bin/agent-vm-tunnel ensure  # reconcile database, app, and tunnel
bin/agent-vm-tunnel status  # show owned processes and recent state
bin/agent-vm-tunnel stop    # stop only this project's app and tunnel
```

Deleting or rotating a preview in the dashboard invalidates its old
credential. Replace the environment variable with the new value and run
`ensure` again.
