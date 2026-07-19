# rstudio-server

Installs and starts **RStudio Server** on your spawn instance, so you get a
browser-based R IDE — editor, console, plots, and package manager — on a machine
sized for the work (lots of RAM, many cores, or a GPU box for R+CUDA).

## How it works

The plugin installs R and RStudio Server on the instance, creates an `rstudio`
login user, and starts the `rstudio-server` service. RStudio listens on port
**8787**. A health check keeps an eye on the service.

Everything runs **on the instance** — there's no controller-side setup and no
secret to pass. It works on both RPM-based (Amazon Linux/RHEL/Rocky) and
Debian/Ubuntu AMIs, on x86_64 and arm64.

## Config

| Key | Default | Description |
|-----|---------|-------------|
| `r_version` | `latest` | R version to install (e.g. `4.3.2`, or `latest`). |
| `password` | `spore` | Password for the `rstudio` login user. **Set your own.** |

## Install

At launch:

```yaml
# launch.yaml
plugins:
  - name: rstudio-server
    config:
      password: <choose-a-strong-password>
```

Or on a running instance:

```bash
spawn plugin install rstudio-server --instance <id> \
  --config password=<choose-a-strong-password>
```

## Connecting

RStudio Server listens on port **8787**. The instance's security group doesn't
open 8787 to the internet, so reach it one of two safe ways:

**SSH tunnel (simplest):**

```bash
ssh -L 8787:localhost:8787 <instance>
# then open http://localhost:8787 and log in as user `rstudio`
```

**Tailscale:** add the [`tailscale`](../tailscale/) plugin too, then browse to
`http://<tailscale-ip>:8787` over the encrypted mesh — no public exposure.

The `url` output reports `http://<public-ip>:8787` for reference, but prefer a
tunnel or Tailscale over opening 8787 publicly.

## Notes

- Log in with username **`rstudio`** and the `password` you set.
- Installing R (and its packages) can take a few minutes on first launch; the
  health check reports the service `active` once it's up.
