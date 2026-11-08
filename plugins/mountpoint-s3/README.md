# mountpoint-s3

Mounts an **Amazon S3 bucket as a local filesystem** on your spawn instance using
[Mountpoint for Amazon S3](https://github.com/awslabs/mountpoint-s3), so tools
that read/write local paths can work against S3 objects directly.

## ⚠️ Precondition: the instance IAM role must have S3 access

Mountpoint uses the **instance's IAM role** for credentials. A plugin runs
post-launch and **cannot** set the instance profile — so you must launch the
instance with a role that already grants access to your bucket (at minimum
`s3:ListBucket` on the bucket and `s3:GetObject`/`s3:PutObject`/`s3:DeleteObject`
on its objects; read-only can drop the writes). If the role lacks access, the
mount will fail with permission errors.

## How it works

The plugin downloads a **pinned** Mountpoint release (1.19.0). spored checks the
package's sha256 and size before anything installs it, and fails the install if
either is wrong. On a current spawn it downloads only the instance's architecture,
an `.rpm` and a `.deb` (about 25 MB). Then it installs the one for the instance's
package manager and runs `mount-s3` as a systemd service (`mountpoint-s3.service`)
that mounts your bucket at `mount_path`. A health check confirms the path is a
live mountpoint. Works on x86_64 and arm64.

## Config

| Key | Default | Description |
|-----|---------|-------------|
| `bucket` | *(required)* | S3 bucket to mount (name only, no `s3://`). |
| `prefix` | *(none)* | Optional key prefix mounted as the filesystem root. |
| `mount_path` | `/mnt/s3` | Local directory to mount at. |
| `read_only` | `false` | Mount read-only. |

## Install

```bash
spawn plugin install mountpoint-s3 --instance <id> \
  --config bucket=my-bucket --config mount_path=/mnt/data
```

Or at launch via a `plugins:` block in `launch.yaml`.

## Notes

- The mount is backed by S3, not a block device — semantics differ from a real
  filesystem (see the Mountpoint docs for supported operations; e.g. no random
  writes to existing objects).
- To upgrade Mountpoint, change all four pinned `fetch` steps in `plugin.yaml`
  together (URL, `sha256`, `size`). Take each pin from a package whose `.asc`
  signature verifies against AWS's key. Then run `scripts/verify-artifact-pins.sh`,
  which downloads each package and checks its sha256, size and AWS signature;
  CI runs it too. Versioned release artifacts are immutable, so a pin stays valid.
- For rich multi-backend sync/copy (Google Drive, other clouds), see the
  [`rclone`](../rclone/) plugin instead.
