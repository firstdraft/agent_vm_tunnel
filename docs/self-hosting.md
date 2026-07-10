---
layout: default
title: Self-hosting
---

# Self-hosting and custom configuration

The default generator targets the shared service at <https://firstdraft.io>.
Most workshop applications do not need any configuration beyond choosing a
provider.

## Use a custom tunnel control plane

Deploy the control/data plane from
[firstdraft/agent-vm-tunnel](https://github.com/firstdraft/agent-vm-tunnel),
then obtain the chisel server fingerprint through an authenticated,
independent operator channel.

Generate the connector with both values:

```bash
bin/rails generate agent_vm_tunnel:install \
  --provider=both \
  --host=preview.example.com \
  --fingerprint='base64-sha256-server-fingerprint='
```

The generator rejects a custom host without a valid 44-character base64
fingerprint.

## Runtime overrides

The generated JSON file is the normal source of shared configuration. Explicit
environment overrides are available for migrations or operator-managed
environments:

```bash
AGENT_VM_TUNNEL_HOST=preview.example.com
AGENT_VM_TUNNEL_FINGERPRINT=base64-sha256-server-fingerprint=
```

Ruby-only exceptions belong in an initializer:

```ruby
# config/initializers/agent_vm_tunnel.rb
AgentVmTunnel.configure do |config|
  config.host = "preview.example.com"
  # config.environments = [:development]
  # config.extra_allowed_hosts = [".example.dev"]
  # config.extra_allowed_origins = [%r{\Ahttps://specific\.example\.dev\z}]
end
```

Normal Action Cable traffic should use exact same-origin. Treat
`extra_allowed_origins` as a narrow application-specific exception, never as a
default sibling-domain wildcard.

## Operator documentation

Provisioning, DNS, backup, migration, reconciliation, and recovery procedures
belong with the control plane. Follow its README and `UPGRADING.md`; do not copy
operator secrets or server commands into an attendee repository.
