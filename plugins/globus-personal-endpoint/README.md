# globus-personal-endpoint

Registers a **Globus Connect Personal** endpoint on your spawn instance so you
can move data to/from it with Globus (fast, resumable, checksummed transfers
between your laptop, HPC systems, and the instance).

## How it works

On your machine (where the Globus CLI is logged in as you), spawn creates a new
personal endpoint and captures its **setup key**, pushes that key to the
instance, and the instance installs Globus Connect Personal and runs
`globusconnectpersonal -setup --setup-key <key>` to register + start it. A fresh
endpoint is created per install and deleted when you remove the plugin or
terminate the instance.

The remote setup runs **as your instance login user, not root** — Globus Connect
Personal refuses to run as root and stores its config under `~/.globusonline`.
The plugin handles this automatically (its remote steps are marked `as_user`);
see [CONCEPTS.md](../../CONCEPTS.md) for what that means.

## What you need to set up (once)

### Install and log in to the Globus CLI on your machine

```bash
pip install globus-cli        # or: pipx install globus-cli
globus login                  # opens a browser to authenticate
```

On a headless controller, use `globus login --no-local-server` and follow the
printed URL. Confirm with:

```bash
globus whoami                 # should print your Globus identity
```

The plugin's local condition runs `globus whoami` and fails early if you're not
logged in.

> **Identity note:** the Globus identity your CLI is logged in as **owns** the
> endpoint spawn creates. If you also run Globus Connect Personal on your laptop
> under a *different* identity, transfers between the two need the same identity
> on both sides (or a Globus login that can see both). If a `globus ls`/transfer
> against an endpoint returns `403 Not authorized`, that's an identity mismatch,
> not a spawn problem.

## Install

```bash
spawn plugin install globus-personal-endpoint --instance <id> \
  --config display_name="my-endpoint"
```

## Verify

```bash
# The endpoint should show GCP Connected: True once it's up:
globus endpoint show <endpoint-id>

# List files on it (proves your CLI identity can reach it):
globus ls <endpoint-id>:/~/
```

Then do a real transfer, e.g. from a Globus Tutorial Collection or your own
laptop endpoint to this one (both directions work):

```bash
globus transfer <src-endpoint>:/path/file  <this-endpoint>:/~/file
```

## Teardown

`spawn plugin remove globus-personal-endpoint --instance <id>` (and
`spawn terminate`) delete the endpoint via `globus endpoint delete`. Prefer
`spawn terminate` over letting an idle/spot instance be reaped — reaper-initiated
termination can't reach your machine to delete the endpoint (see the caveat in
CONCEPTS.md).

## Config

| Key | Required | Default | Description |
|-----|----------|---------|-------------|
| `display_name` | no | `spore-endpoint` | Display name for the Globus endpoint |

## Requirements & notes

- **Linux instance.** Globus Connect Personal is x86_64 and aarch64 capable; the
  plugin installs the current Linux build.
- The instance needs outbound network to the Globus relay
  (`relay.globusonline.org:2223`) — the default spawn security group allows all
  outbound, so this works out of the box.
