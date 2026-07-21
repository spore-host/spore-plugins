# rclone

Installs **rclone** on your spawn instance and mounts one of your existing rclone
remotes (Google Drive, S3, Dropbox, Backblaze, SFTP, …) at a local path — so
tools that read/write local files work against that remote.

## How it works (your config, pushed — no interactive auth on the instance)

You configure the remote **once on your own machine** with `rclone config`
(including any OAuth browser flow). At install, the plugin reads your local
`~/.config/rclone/rclone.conf`, `push`es it to the instance, writes it for
`ec2-user`, and mounts the named remote via a systemd service (FUSE). Because the
authed config is pushed, **OAuth remotes work without any login on the instance**.

The pushed config contains the remote's tokens — treat it like the globus
setup-key handoff: it's a controller→instance secret transfer over spawn's
existing push channel.

## Config

| Key | Default | Description |
|-----|---------|-------------|
| `remote` | *(required)* | Name of a remote in your local `rclone.conf` (e.g. `gdrive`). |
| `path` | *(none)* | Optional path within the remote to mount as the root. |
| `mount_path` | `/mnt/rclone` | Local directory to mount at. |

## Install

```bash
# once, on your machine:
rclone config          # create a remote named e.g. 'gdrive'

spawn plugin install rclone --instance <id> \
  --config remote=gdrive --config mount_path=/mnt/gdrive
```

## Why no automatic smoke

The plugin's value is mounting **your** authed remote, which needs your
`rclone.conf` (and, for OAuth remotes, a browser flow you complete locally). It
ships **static-validated** with this recipe rather than an automated real-AWS
smoke. The install/config-push/mount flow mirrors the globus plugin.

## Notes

- The whole `rclone.conf` is pushed (all remotes in it), not just the named one —
  keep that file scoped to what you're comfortable copying to the instance.
- FUSE mounting needs root and `user_allow_other` (the plugin sets it).
- For S3 specifically with the instance IAM role (no pushed secret), prefer
  [`mountpoint-s3`](../mountpoint-s3/).
