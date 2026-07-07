# agent_vm_tunnel

Public live-preview URLs for Rails apps you build inside a **Claude Cloud VM**
(claude.ai/code) — or any sandbox that can't accept inbound connections.

A Cloud VM has no port-forwarding and its egress is a TLS-intercepting proxy, so
you can't just open `localhost:3000` in a browser, and `cloudflared`/`ngrok`
don't get through. This gem exposes your running dev server at
`https://<you>-<app>.firstdraft.io` through a self-hosted
[chisel](https://github.com/jpillora/chisel) reverse tunnel (WebSocket over 443,
which the proxy *does* forward). Each app you build gets its own preview URL and
its own credential.

Two moving parts, both installed for you:

- a **Railtie** that allows the tunnel's hosts and Action Cable origins, so
  tunneled page loads and Turbo Streams / live reload aren't rejected — no
  editing of `config/environments`.
- a **keep-alive script** (`bin/agent-vm-tunnel`) plus **Claude Code hooks** that bring
  Postgres + the app + the tunnel up on session start and every turn, and
  self-heal after the VM reaps them on idle.

The tunnel server itself lives in
[firstdraft/agent-vm-tunnel](https://github.com/firstdraft/agent-vm-tunnel);
this gem is the client half you add to the Rails app you're previewing.

## Install

Add it to the app you want to preview:

```ruby
# Gemfile
gem "agent_vm_tunnel"
```

```bash
bundle install
bin/rails generate agent_vm_tunnel:install
```

The generator adds:

| File | What it's for |
|---|---|
| `bin/agent-vm-tunnel` | Idempotent keep-alive: Postgres + the app + the chisel tunnel |
| `cloud-vm-setup.sh` | One-shot Cloud VM provisioning (Ruby, Postgres, gems, chisel) |
| `.claude/settings.json` | `SessionStart` + `UserPromptSubmit` hooks that run `bin/agent-vm-tunnel` |

It **merges** into an existing `.claude/settings.json` — your other hooks and
settings are left alone.

## Use it (Claude Cloud VM)

1. **Create a preview for this app** at <https://firstdraft.io> (one per app —
   name it, e.g. `blog`) and copy the one line it shows:
   `AGENT_VM_TUNNEL=<slot>:<password>`.
2. In your Cloud VM (**claude.ai/code → Add cloud environment**):
   - **Setup script** → point it at this repo's `cloud-vm-setup.sh`
   - **Environment variables** → paste that app's `AGENT_VM_TUNNEL` line (persists across sessions)
   - **Network access** → **Full** (the tunnel needs unrestricted egress; *Trusted* blocks it)
3. **Start a session.** The hooks run `bin/agent-vm-tunnel` every turn, so the app +
   tunnel come up on their own. Open `https://<you>-<app>.firstdraft.io`.

Run `bin/agent-vm-tunnel` by hand any time to force a (re)start. The preview URL is
public — turn on Basic Auth from the dashboard if you want a lock on it.

## Configuration

By default everything targets the shared **firstdraft.io** tunnel. Nothing to
configure to use it.

### Point at your own tunnel box

If you run your own [agent-vm-tunnel](https://github.com/firstdraft/agent-vm-tunnel)
server, set the host once — the generator bakes it into `bin/agent-vm-tunnel` and
`cloud-vm-setup.sh`:

```bash
bin/rails generate agent_vm_tunnel:install --host preview.example.com
```

And tell the Railtie the same host (so it allows the right hosts/origins),
either with an env var:

```bash
AGENT_VM_TUNNEL_HOST=preview.example.com
```

or an initializer:

```ruby
# config/initializers/agent_vm_tunnel.rb
AgentVmTunnel.configure do |config|
  config.host = "preview.example.com"
  # config.environments = [:development]      # where the Railtie applies
  # config.allow_localhost = true             # also allow http://localhost:* cable origins
  # config.extra_allowed_hosts = [".example.dev"]
  # config.extra_allowed_origins = [%r{\Ahttps://.*\.example\.dev\z}]
end
```

The generator also takes `--fingerprint` if your server's chisel fingerprint
isn't discoverable at `https://<host>/tunnel` on first connect.

## How the Railtie config maps

For host `firstdraft.io` the Railtie is equivalent to adding this to
`config/environments/development.rb`:

```ruby
config.hosts << ".firstdraft.io"
config.action_cable.allowed_request_origins = [
  %r{\Ahttps://[a-z0-9-]+\.firstdraft\.io\z},
  %r{\Ahttp://localhost:\d+\z}
]
```

except it merges with (rather than replaces) any origins already configured, and
only applies in the environments you list.

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
