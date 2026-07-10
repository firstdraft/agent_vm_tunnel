---
layout: default
title: Security
---

# Security model

Agent VM Tunnel makes a development server reachable from the public internet.
Treat the preview as a deployment of development code, not as a private
localhost tab.

## Opaque URLs are not credentials

Preview hostnames are random and reveal neither a GitHub login nor an app name.
That reduces accidental identity disclosure and makes guessing impractical, but
the URL is still shareable and public. Do not rely on obscurity for sensitive
data.

Enable Basic Auth in the dashboard when a preview should require an additional
browser credential. Avoid entering production data, real customer records, or
long-lived secrets in preview applications.

## Protect `AGENT_VM_TUNNEL`

The `AGENT_VM_TUNNEL=<slot>:<password>` value authorizes a reverse tunnel to a
specific preview. Store it in the cloud provider's environment configuration,
never in:

- the repository or committed dotenv files;
- issue descriptions, chat transcripts, screenshots, or build logs; or
- shell commands that are copied into documentation.

Deleting or releasing the preview invalidates the lease. Re-leasing rotates
the password and disconnects the old tunnel session.

One credential maps to one reverse port. A repository generated for `both` may
be installed in both providers, but concurrently running Codex and Claude
containers should receive separate preview credentials.

## Server identity is pinned

The generated connector pins the chisel server's SHA-256 fingerprint in
`config/agent_vm_tunnel.json`. A public coordinates response may update the
HTTPS connect URL, but it cannot replace the fingerprint. This prevents a
TLS-intercepting proxy or compromised coordinates endpoint from silently
substituting another tunnel server.

## Browser origins remain isolated

The Railtie permits the configured host suffix for ordinary Rails host
authorization. It does not add a wildcard Action Cable origin. Rails' exact
same-origin check remains in force, preventing a page on one sibling preview
from opening an authenticated WebSocket to another.

Only add `extra_allowed_origins` for a specific application requirement you
understand. Do not add a blanket `*.firstdraft.io` Cable origin.

## Least-privilege network access

The connector needs outbound HTTPS/WebSocket access to the tunnel service. On
providers that support domain allowlists, permit only the configured control
and tunnel hosts. Setup may additionally need package registries; provider
setup phases commonly handle those separately from agent runtime access.
