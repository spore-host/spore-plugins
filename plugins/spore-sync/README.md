# spore-sync

Keeps a local directory on your machine and a directory on the spawn instance in
**continuous, live, bidirectional sync** using [mutagen](https://mutagen.io) —
edit files on either side and they propagate to the other, like a shared folder.

## How it works

The sync runs from your machine: spawn's local provision step creates a mutagen
session (`mutagen sync create`) between your chosen local directory and a
directory on the instance, reached over SSH. mutagen then watches both sides and
syncs changes continuously in the background. There's no agent to install for
the sync itself — mutagen on your machine drives it.

## What you need to set up (once)

### Install mutagen on your machine

```bash
brew install mutagen-io/mutagen/mutagen
mutagen version         # confirm it's on PATH
```

The plugin's local condition runs `mutagen version` and fails early if it's
missing.

You also need to be able to SSH to the instance as your login user — spawn sets
this up automatically (it configures the instance's SSH identity for you during
install), so no manual key/agent step is required.

## Install

```bash
spawn plugin install spore-sync --instance <id> \
  --config local_path=/path/on/your/machine \
  --config remote_path=/home/<you>/synced
```

- `local_path` (**required**) — the directory on your machine to sync. Pick a
  project/working directory; mutagen will keep its entire contents in sync.
- `remote_path` (optional) — where it lands on the instance (default
  `/home/ec2-user/sync`; set it under your instance home, e.g.
  `/home/<your-username>/synced`).
- `mode` (optional) — mutagen sync mode (default `two-way-safe`).

## Verify

```bash
mutagen sync list                     # shows the spore-<instance> session, "Watching for changes"
echo hello > /path/on/your/machine/test.txt
# a moment later, on the instance:
#   cat <remote_path>/test.txt   → hello
```

Edits on the instance flow back to your machine the same way.

## After a stop/start

Stopping and starting an instance gives it a **new public IP**. The old mutagen
session is pinned to the previous address and can't follow it, so spore-sync
declares a `reconcile` step: `spawn start` automatically tears down the stale
session and recreates it against the new IP. You don't need to do anything.

## Teardown

`spawn plugin remove spore-sync` (and `spawn terminate`) run
`mutagen sync terminate` to stop the session on your machine. Prefer
`spawn terminate` — a reaper/spot termination can't reach your machine to stop
the session (it will show as disconnected; `mutagen sync terminate spore-<name>`
clears it).

## `two-way-safe` and conflicts

The default `two-way-safe` mode **won't silently overwrite**: if the *same* file
is changed on both sides while disconnected (e.g. during a stop), mutagen flags a
**conflict** and leaves both versions rather than picking a winner —
`mutagen sync list` shows it, and you resolve it. New/independent files on either
side sync normally. This is intended data-safety behavior, not a failure.

## Config

| Key | Required | Default | Description |
|-----|----------|---------|-------------|
| `local_path` | yes | — | Directory on your machine to sync |
| `remote_path` | no | `/home/ec2-user/sync` | Directory on the instance |
| `mode` | no | `two-way-safe` | mutagen sync mode (`two-way-safe`, `two-way-resolved`, `one-way-safe`, `one-way-replica`) |
