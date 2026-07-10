---
layout: default
title: Troubleshooting
---

# Troubleshooting

Start with one command inside the cloud environment:

```bash
bin/agent-vm-tunnel status
```

Then use the symptom below. Avoid deleting generated state until you have read
the referenced log; it often contains the precise failure.

## `AGENT_VM_TUNNEL` is missing or invalid

Confirm the environment contains exactly one value shaped like:

```text
AGENT_VM_TUNNEL=42:a-long-random-password
```

In Codex, this must be an **environment variable**, not a setup-only secret.
In Claude, add it to the cloud environment's environment-variable field. Do
not wrap the whole line in shell quotes in the provider UI.

If the dashboard rotated the credential, replace the entire old value and run:

```bash
bin/agent-vm-tunnel ensure
```

The connector stops an old owned tunnel before accepting replacement
credentials.

## The setup script cannot find Ruby

Commit an exact `.ruby-version` supported by the application. Then reset or
rebuild the cloud environment so setup runs again.

The script first uses the exact Ruby from the provider, asdf, or mise. On an
x86_64 Linux environment where none is available, it can install the exact
portable ruby-builder release into `/opt/hostedtoolcache`.

## Setup exceeds the provider's build window

Make sure `Gemfile.lock` includes the cloud platform:

```bash
bundle lock --add-platform x86_64-linux
bundle cache --all-platforms
```

Commit `vendor/cache` if network installation dominates setup time. Prefer
precompiled Linux gems. A fully installed `vendor/bundle` is much larger and
should be a last resort.

## The app process is down

Read the app log:

```bash
tail -n 100 tmp/agent-vm-tunnel/app.log
```

Check that the normal development command can boot and that it respects
`PORT`. The connector starts the app on `127.0.0.1` and uses port `3000` unless
`APP_PORT` is set.

## The tunnel process is down

Read the tunnel log:

```bash
tail -n 100 tmp/agent-vm-tunnel/tunnel.log
```

Common causes are:

- agent/runtime internet access is off;
- the control or tunnel domain is absent from the provider allowlist;
- a stale or released dashboard credential; or
- a fingerprint mismatch after pointing the project at a different server.

Do not bypass fingerprint verification. Regenerate with a fingerprint obtained
independently from the self-hosted operator.

## The preview shows “asleep” or a gateway error

Run:

```bash
bin/agent-vm-tunnel ensure
bin/agent-vm-tunnel status
```

If both processes are running, verify the Rails app locally inside the cloud
environment:

```bash
curl -fsS http://127.0.0.1:${APP_PORT:-3000}/up
```

An application-level failure here is not a tunnel failure.

## HTTP works but Turbo or Action Cable does not

Open the browser developer console and inspect the WebSocket request. It must
use the same public preview host as the page. Remove any copied wildcard Cable
origin configuration and allow Rails' exact same-origin check to handle the
forwarded host and HTTPS scheme.

The [demo app](https://github.com/firstdraft/agent-vm-tunnel-demo) isolates
this check with a two-tab Turbo broadcast.

## Reset only this project's processes

```bash
bin/agent-vm-tunnel stop
bin/agent-vm-tunnel ensure
```

These commands act only on processes carrying this project's ownership marker.
They do not use a global `pkill` or interfere with another checkout.
