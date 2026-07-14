# How spore-host plugins work

This explains the concepts you need to understand *why* a plugin asks you to do
certain things before it will work. If you just want the steps for one plugin,
see its `plugins/<name>/README.md`. Read this once and the per-plugin setup
makes sense.

## The two halves: controller and instance

A plugin has steps that run in two places:

- **Controller (local)** — your own machine, where you run `spawn`. This is
  where you're already authenticated to services (you've run `globus login`, you
  have Tailscale credentials, `mutagen` is installed). Steps here are the
  plugin's `local.*` blocks.
- **Instance (remote)** — the EC2 instance spawn launched. Steps here are the
  plugin's `remote.*` blocks, executed by `spored` (the spawn agent on the
  instance).

`spawn plugin install` runs **both halves in one command**: it runs the local
provision steps on your machine first, then hands the plugin to `spored` to run
the remote steps.

Why this split matters: the controller is the *only* place that holds your
service credentials. So the common, secure pattern is **mint a short-lived,
scoped credential locally → push it to the instance → the instance uses it**.
You never copy your long-lived secret onto the instance. Both Tailscale and
Globus work exactly this way.

```
your machine (authenticated)          the instance
  local.provision                       remote.install / configure / start
  ─ create a scoped token   ──push──▶   ─ use the token to join/register
```

## Prerequisites live on your machine, not the instance

Because the local half runs on your machine, a plugin's prerequisites are things
*you* set up locally, once:

- **Tailscale** — a Tailscale OAuth client (to mint node keys) + an ACL tag it
  can grant. `curl` and `jq` installed locally.
- **Globus** — `globus login` (the CLI logged in as you) so it can create an
  endpoint on your behalf.
- **spore-sync** — `mutagen` installed locally (it drives the sync from your
  machine).

Each plugin's `README.md` walks through its specific setup. The plugin's local
**conditions** check these are in place and fail early with a helpful message if
not — so a missing prerequisite is caught before anything launches, not halfway
through.

## Passing controller secrets to a local step: `env_passthrough`

Local plugin steps run with a **deliberately minimal environment** — spawn
strips your shell's environment so a plugin script can't quietly read your
`AWS_*` keys or other secrets. `PATH` and `HOME` are kept (so tools are found);
everything else is dropped.

When a plugin legitimately needs one of your environment variables (e.g.
Tailscale's `TS_API_CLIENT_SECRET` to mint a key), it declares exactly which
ones under `local.env_passthrough`, and spawn injects *only* those. This is why
Tailscale asks you to `export TS_API_CLIENT_ID=… TS_API_CLIENT_SECRET=…` before
installing — the plugin opts those two in by name, and nothing else leaks.

## Running a remote step as your user, not root: `as_user`

`spored` runs remote steps as **root** by default. Some tools refuse that or
store per-user state — notably Globus Connect Personal, which aborts with
"Running Globus Connect Personal as root is not supported" and keeps its config
under `~/.globusonline`. A remote step can set `as_user: true` to run as the
instance's **local login user** (see below) instead. You don't configure this —
it's set in the plugin spec where needed — but it's why Globus works headlessly.

## Who you are on the instance (the local-matching user)

spawn creates a Linux user on the instance that **matches your controller login
name** and installs your SSH key for it, so `spawn connect` logs you in as *you*
(e.g. `scttfrdmn`), not a generic `ec2-user`. Names with capitals or dots are
normalized to a valid Linux login (`SFriedman` → `sfriedman`, `john.doe` →
`john-doe`).

This matters for plugins in two ways: `as_user` steps run as this user, and a
plugin that stores per-user state (like Globus) does so under this user's home.

> **Windows:** there is no per-user account — your key is authorized for the
> built-in `Administrator`, and `spawn connect` logs in as `Administrator`.
> The local-matching-user model is Linux-only.

## Lifecycle: install, reconcile, remove

- **install** — local provision, then remote install → configure → start.
  Values captured locally and `push`ed are delivered before the remote configure
  runs, so a remote step can use `{{ pushed.<key> }}`.
- **`spawn start` (after a stop)** — a stopped instance gets a **new public IP**
  when restarted. A plugin whose local footprint is pinned to the address (e.g.
  spore-sync's mutagen session) declares `local.reconcile` steps that spawn
  replays with the new IP. Address-independent plugins (Tailscale is an overlay
  network; Globus uses a relay) don't need this.
- **`spawn plugin remove` / `spawn terminate`** — runs the plugin's
  `local.deprovision` to tear down what it created on your machine or account
  (e.g. delete the Globus endpoint, stop the mutagen session). Tailscale needs
  no deprovision: its nodes are *ephemeral* and auto-remove from your tailnet
  when the instance disconnects.

> **Caveat:** reaper- or spot-initiated termination happens without your
> controller, so it can't run local deprovision. For plugins that leave a
> controller/account footprint (Globus, spore-sync), prefer `spawn terminate`
> to clean up. Tailscale is self-cleaning regardless.

## Readiness

`spawn plugin install` waits for the instance to be **fully provisioned** (the
same signal `spawn launch` uses) before running remote steps — so the plugin
isn't racing cloud-init. You don't need to time anything; install when the
launch returns.
