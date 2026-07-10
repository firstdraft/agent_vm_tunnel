# agent_vm_tunnel

Public live-preview URLs for Rails apps you build inside a **Claude or Codex
Cloud environment** — or another Linux sandbox that can't accept inbound
connections.

A Cloud VM has no port-forwarding and its egress is a TLS-intercepting proxy, so
you can't just open `localhost:3000` in a browser, and `cloudflared`/`ngrok`
don't get through. This gem exposes your running dev server at
`https://<you>-<app>.firstdraft.io` through a self-hosted
[chisel](https://github.com/jpillora/chisel) reverse tunnel (WebSocket over 443,
which the proxy *does* forward). Each app you build gets its own preview URL and
its own credential.

Two moving parts, both installed for you:

- a **Railtie** that allows the tunnel's hosts. Action Cable retains Rails'
  exact same-origin protection, so one preview cannot open authenticated
  WebSockets to a sibling preview.
- a locked, project-owned **maintenance script** (`bin/agent-vm-tunnel`) that
  reconciles the database, app, and tunnel after an environment resumes.

The tunnel server itself lives in
[firstdraft/agent-vm-tunnel](https://github.com/firstdraft/agent-vm-tunnel);
this gem is the client half you add to the Rails app you're previewing.

## Install

Add it to the app you want to preview:

```ruby
# Gemfile
gem "agent_vm_tunnel", github: "firstdraft/agent_vm_tunnel"
# once it's released on RubyGems, this becomes just: gem "agent_vm_tunnel"
```

```bash
bundle install
bin/rails generate agent_vm_tunnel:install --provider=claude
```

The generator adds:

| File | What it's for |
|---|---|
| `bin/agent-vm-tunnel` | Idempotent keep-alive: the database + the app + the chisel tunnel |
| `cloud-vm-setup.sh` | One-shot Cloud VM provisioning (Ruby, your database, gems, chisel) |
| `config/agent_vm_tunnel.json` | Shared, pinned host/fingerprint/provider configuration |
| `.claude/settings.json` | `SessionStart` + `UserPromptSubmit` hooks that run `bin/agent-vm-tunnel` |

It **merges** into an existing `.claude/settings.json` — your other hooks and
settings are left alone.

## Use it (Claude Cloud VM)

1. **Get access and create a preview.** Open the invite link the tunnel operator
   sent you, sign in with GitHub at <https://firstdraft.io>, and create a preview
   for this app (one per app — name it, e.g. `blog`). Copy the one line it shows:
   `AGENT_VM_TUNNEL=<slot>:<password>`.
2. In your Cloud VM (**claude.ai/code → Add cloud environment**), set three fields:
   - **Setup script** → paste this. The field runs at build time and may not start
     in your repo's directory, so it finds the repo first, then runs the generated
     `cloud-vm-setup.sh`:
     ```bash
     #!/bin/bash
     set -e
     repo="${CLAUDE_PROJECT_DIR:-}"
     [ -f "$repo/cloud-vm-setup.sh" ] || repo="$(find / -maxdepth 6 -name cloud-vm-setup.sh -printf '%h\n' 2>/dev/null | head -n1)"
     cd "$repo"
     bash cloud-vm-setup.sh
     ```
     (The dashboard shows this same snippet with a **Copy** button.)
   - **Environment variables** → paste that app's `AGENT_VM_TUNNEL` line (persists across sessions)
   - **Network access** → **Full** (the tunnel needs unrestricted egress; *Trusted* blocks it)
3. **Start a session.** The hooks run `bin/agent-vm-tunnel` every turn, so the app +
   tunnel come up on their own. Open `https://<you>-<app>.firstdraft.io`.

Run `bin/agent-vm-tunnel ensure` by hand any time to reconcile state, or
`bin/agent-vm-tunnel status` to inspect it. The preview URL is
public — turn on Basic Auth from the dashboard if you want a lock on it.

## Use it (Codex Cloud)

Generate the same provider-neutral scripts without Claude project hooks:

```bash
bin/rails generate agent_vm_tunnel:install --provider=codex
```

Configure `cloud-vm-setup.sh` as the environment setup command and
`bin/agent-vm-tunnel ensure` as its maintenance command. Add the dashboard's
`AGENT_VM_TUNNEL` value to the environment and permit runtime HTTPS/WebSocket
egress to the configured tunnel host. Provider-specific behavior stays behind
the explicit `--provider` option; `--provider=generic` generates scripts only.

## Configuration

By default everything targets the shared **firstdraft.io** tunnel. Nothing to
configure to use it.

### Point at your own tunnel box

If you run your own [agent-vm-tunnel](https://github.com/firstdraft/agent-vm-tunnel)
server, set the host and independently obtained chisel fingerprint once. The
generator writes both to the single configuration consumed by Rails and the
maintenance script:

```bash
bin/rails generate agent_vm_tunnel:install \
  --host preview.example.com \
  --fingerprint 'base64-chisel-server-fingerprint='
```

`AGENT_VM_TUNNEL_HOST` can override that host at runtime for both components.
`AGENT_VM_TUNNEL_FINGERPRINT` similarly provides an explicit pin override.

```bash
AGENT_VM_TUNNEL_HOST=preview.example.com
```

Ruby-only settings still belong in an initializer:

```ruby
# config/initializers/agent_vm_tunnel.rb
AgentVmTunnel.configure do |config|
  config.host = "preview.example.com"
  # config.environments = [:development]      # where the Railtie applies
  # config.extra_allowed_hosts = [".example.dev"]
  # Explicit exceptions only; normal Cable traffic uses exact same-origin.
  # config.extra_allowed_origins = [%r{\Ahttps://.*\.example\.dev\z}]
end
```

The public coordinates endpoint may update only `connect_url`; its fingerprint
is ignored so a TLS-intercepting proxy cannot replace the independently pinned
chisel identity.

## How the Railtie config maps

For host `firstdraft.io` the Railtie is equivalent to adding this to
`config/environments/development.rb`:

```ruby
config.hosts << ".firstdraft.io"
```

Action Cable sees the public Host and `X-Forwarded-Proto` preserved by the
reverse proxy, so Rails' built-in exact same-origin check accepts Turbo Streams
without a wildcard sibling-domain exception. Explicit extra origins are merged,
never substituted.

## Slow VM setup? Vendor your gems

The Cloud VM runs `cloud-vm-setup.sh` under a **~5-minute build budget**.
Installing Ruby is quick (a prebuilt tarball); the variable is `bundle install` —
a large Gemfile that fetches and compiles native extensions over the network can
blow the budget. If it does, vendor your gems so the install is offline and mostly
precompiled.

The VM is `x86_64-linux`, which is probably not your machine's platform, so add it
to the lockfile and cache every platform's gems:

```bash
bundle lock --add-platform x86_64-linux
bundle cache --all-platforms          # writes .gem files into vendor/cache
git add -f Gemfile.lock vendor/cache
```

Commit that, and `bundle install` on the VM installs from `vendor/cache` with no
downloads — and no compilation for gems that ship precompiled `x86_64-linux`
builds, which most popular native gems (nokogiri, sqlite3, …) do.

For the absolute minimum VM time you can go further and commit a fully-installed
`vendor/bundle` built on a Linux machine (zero install on the VM), but that's
heavier to produce and keep in sync — reach for it only if `vendor/cache` isn't
enough.

## Requirements

- Rails 7.0+ (Railtie + generator via `railties`)
- Ruby 3.3+ (the app's own version is read from `.ruby-version`)
- An app whose `bin/dev` (or `bin/rails server`) listens on `:3000` (override
  with `APP_PORT`). SQLite, PostgreSQL, and MySQL/MariaDB all work — the
  generated `cloud-vm-setup.sh` detects the adapter from your lockfile and
  provisions accordingly (SQLite needs no server).

## Development

```bash
bin/setup          # install deps
bundle exec rake   # tests + Standard
```

## License

Released under the [MIT License](LICENSE.txt).
