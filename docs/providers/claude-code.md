---
layout: default
title: Claude cloud environment
---

# Set up a Claude cloud environment

Claude's cloud-environment screen and lifecycle model differ from Codex Cloud.
Use this page only after generating the connector with `--provider=claude` or
`--provider=both` and pushing the generated files.

If a Codex environment for the same repository may run concurrently, create a
separate dashboard preview for Claude. Reusing one credential is appropriate
only when the two environments are never active at the same time.

The generator merges two command hooks into `.claude/settings.json`:
`SessionStart` and `UserPromptSubmit`. Both safely call
`bin/agent-vm-tunnel ensure`; existing hooks remain intact.

## 1. Add the environment

In Claude, open **Code**, choose **Add cloud environment**, and select the
GitHub repository and branch for this application.

Fill in the Claude-specific fields:

| Claude field | Value |
|---|---|
| Setup script | Use the wrapper below |
| Environment variables | `AGENT_VM_TUNNEL=<slot>:<password>` from the matching dashboard preview |
| Network access | **Full** |

Claude may start its setup field outside the checked-out repository. Paste this
wrapper rather than only `bash cloud-vm-setup.sh`:

```bash
#!/bin/bash
set -euo pipefail

repo="${CLAUDE_PROJECT_DIR:-}"
if [ ! -f "$repo/cloud-vm-setup.sh" ]; then
  repo="$(find / -maxdepth 6 -name cloud-vm-setup.sh -printf '%h\n' 2>/dev/null | head -n1)"
fi

test -n "$repo" && test -f "$repo/cloud-vm-setup.sh"
cd "$repo"
exec bash cloud-vm-setup.sh
```

The tunnel needs outbound WebSocket-over-HTTPS access. In the current Claude
environment form, **Trusted** network access blocks that path; select **Full**.

## 2. Start a session

After the environment finishes building, start a Claude Code session in the
repository. The generated `SessionStart` hook calls `ensure`. The prompt hook
calls it again before later work, which repairs processes after an idle sleep.

To verify manually:

```bash
bin/agent-vm-tunnel status
bin/agent-vm-tunnel ensure
```

Open the opaque preview URL shown by <https://firstdraft.io>. The app name and
GitHub username are intentionally absent from the public hostname.

## 3. Regeneration and existing settings

Running the generator again does not duplicate its hooks. It finds an existing
Agent VM Tunnel command in each event and preserves unrelated Claude settings.

If you switch this repository to Codex Cloud, regenerate with
`--provider=codex` and remove the two Agent VM Tunnel hook entries from
`.claude/settings.json` if Claude will no longer use the repository.
