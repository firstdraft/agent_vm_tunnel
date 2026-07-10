# Agent VM Tunnel

Give a Rails app running inside Codex Cloud, a Claude cloud environment, or
another outbound-only Linux sandbox a stable public HTTPS preview URL.

**[Read the documentation](https://firstdraft.github.io/agent_vm_tunnel/)**

```text
browser -> https://p-<opaque>.firstdraft.io -> Caddy -> chisel -> Rails :3000
```

The gem installs the application-side pieces:

- a Railtie that permits preview hosts while retaining Rails' exact
  same-origin Action Cable protection;
- `bin/agent-vm-tunnel`, an idempotent supervisor for the database, Rails app,
  and reverse tunnel;
- `cloud-vm-setup.sh`, a provider-neutral environment setup script; and
- provider lifecycle integration: Claude hooks or Codex environment guidance.

The control plane and tunnel server live in
[firstdraft/agent-vm-tunnel](https://github.com/firstdraft/agent-vm-tunnel).

## Start here

Add the gem to the Rails application you want to preview:

```ruby
gem "agent_vm_tunnel", github: "firstdraft/agent_vm_tunnel"
```

```bash
bundle install

# Choose one provider, or install both integrations:
bin/rails generate agent_vm_tunnel:install --provider=codex
bin/rails generate agent_vm_tunnel:install --provider=claude
bin/rails generate agent_vm_tunnel:install --provider=both
```

Then follow the guide for the environment you are creating:

- [Codex Cloud setup](https://firstdraft.github.io/agent_vm_tunnel/providers/codex-cloud.html)
- [Claude cloud environment setup](https://firstdraft.github.io/agent_vm_tunnel/providers/claude-code.html)
- [Complete quickstart](docs/quickstart.md)

Your tunnel dashboard supplies two things that are intentionally not committed:
an opaque preview URL and an `AGENT_VM_TUNNEL=<slot>:<password>` credential.
The `both` target makes one repository portable across providers. If Codex and
Claude may run it simultaneously, create a separate dashboard preview and
credential for each environment so they do not compete for one reverse port.

## Documentation

| Guide | Use it for |
|---|---|
| [How it works](docs/concepts.md) | The browser-to-container path and process lifecycle |
| [Security model](docs/security.md) | Credentials, public URLs, Basic Auth, origin isolation, and pinning |
| [Troubleshooting](docs/troubleshooting.md) | Setup failures, sleeping previews, logs, and recovery commands |
| [Self-hosting and configuration](docs/self-hosting.md) | A custom tunnel host, fingerprint, or control plane |
| [Demo application](https://github.com/firstdraft/agent-vm-tunnel-demo) | An end-to-end HTTP, health, and Action Cable smoke target |

## Requirements

- Rails 7.0 or newer
- Ruby 3.3 or newer, with an exact version in `.ruby-version`
- SQLite, PostgreSQL, or MySQL/MariaDB
- An app that can listen on `127.0.0.1:3000`; set `APP_PORT` to override the
  port

## Development

```bash
bin/setup
bundle exec rake
```

Released under the [MIT License](LICENSE.txt).
