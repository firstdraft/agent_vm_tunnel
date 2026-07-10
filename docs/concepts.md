---
layout: default
title: How it works
---

# How it works

Cloud development environments can make outbound HTTPS connections but do not
offer a stable inbound port for a workshop browser. Agent VM Tunnel bridges
that gap with one authenticated reverse connection.

```text
                        public internet
browser  ----------------------------------------------+
                                                       |
                                                       v
                                             Caddy on :443
                                                       |
                                                       v
cloud environment -> chisel over WebSocket/TLS -> loopback slot port
       ^                                               |
       |                                               |
       +------------ Rails on 127.0.0.1:3000 <---------+
```

## Control plane and connector

The control plane at <https://firstdraft.io> owns preview leases. Each lease
has an opaque hostname, a reverse port, and a unique chisel credential. Caddy
routes that hostname only to its assigned loopback port.

The connector in the Rails repository owns three local processes:

1. the development database when the selected adapter needs a service;
2. the Rails development server; and
3. the chisel client that reverse-forwards Rails to the leased port.

`bin/agent-vm-tunnel ensure` serializes concurrent calls and records owned
process IDs and configuration hashes under `tmp/agent-vm-tunnel/`. It restarts
only the parts whose inputs changed. It does not use broad process-name matches
and does not stop another project.

## Sleep and resume

Cloud containers are routinely suspended and resumed. The generated setup
script prepares a new environment; provider lifecycle automation subsequently
calls `ensure` whenever a cached environment resumes or a new coding session
starts. Repeating either operation is safe.

## HTTP and WebSockets

Caddy preserves the public host and forwarded HTTPS scheme. The Railtie permits
the configured preview host suffix. Action Cable retains Rails' exact
same-origin validation, so a page on one preview cannot open an authenticated
WebSocket to a sibling preview.
