# tailscale

Joins your spawn instance to your Tailscale network (tailnet), so you can reach
it by its Tailscale IP/name over an encrypted WireGuard mesh — no public SSH
exposure needed.

## How it works

spawn mints a **short-lived, single-use, ephemeral, tagged** Tailscale auth key
on your machine (using your OAuth client), pushes it to the instance, and the
instance runs `tailscale up` to join. Your OAuth *secret* never leaves your
machine — only a one-shot key does. Because the node is **ephemeral**, it
**auto-removes** from your tailnet when the instance stops or is terminated, so
there's nothing to clean up.

See [CONCEPTS.md](../../CONCEPTS.md) for the mint-locally-push pattern.

## What you need to set up (once)

### 1. Local tools

```bash
brew install jq          # curl is already on macOS/Linux
```

The plugin's local condition checks both are present.

### 2. A tailnet ACL tag your instances will get (tagOwners)

Auth keys created by an OAuth client **must be tagged**, and the tag must be
*owned* by the client. Open your tailnet's **access control policy file**
(<https://login.tailscale.com/admin/acls> → the raw/JSON policy editor, *not* the
visual "Add rule" form) and add a `tagOwners` block:

```jsonc
{
  "tagOwners": {
    "tag:spore-oauth": ["autogroup:admin"],   // the tag your OAuth client carries
    "tag:spore":       ["tag:spore-oauth"]     // the tag your instances get
  }
  // ... keep any existing keys (acls/grants/etc.) alongside this
}
```

- `tag:spore` — assigned to each instance (you pass it as `--config tag=tag:spore`).
- `tag:spore-oauth` — owns `tag:spore`, so a key minted by the client (which
  carries `tag:spore-oauth`) is allowed to create a `tag:spore` node.

Save the policy file.

### 3. An OAuth client with the `auth_keys` scope

At <https://login.tailscale.com/admin/settings/oauth> → **Generate OAuth client**:

- **Settings step:** choose **OAuth**, give it a description (e.g. `spore-host`).
- **Scopes step:** keep **Custom scopes**, expand **Keys**, and check **Write**
  on **Auth Keys**. When you check Write it requires a tag — select
  **`tag:spore-oauth`** (the tag you made an owner above).
- **Generate**, then copy the **Client ID** and **Client Secret** (the secret is
  shown only once).

### 4. Export the credentials

In the shell where you'll run spawn:

```bash
export TS_API_CLIENT_ID=<client-id>
export TS_API_CLIENT_SECRET=<client-secret>
```

The plugin reads these via `local.env_passthrough` — only these two variables
are exposed to the mint step, nothing else from your shell.

## Install

```bash
spawn plugin install tailscale --instance <id> --config tag=tag:spore
```

`tag` is required and must match the device tag you set up in step 2.

## Verify

On the instance, `tailscale status` shows it connected; the node appears in your
tailnet (<https://login.tailscale.com/admin/machines>) tagged `tag:spore`.

## Teardown

Nothing to do — the node is ephemeral and disappears from your tailnet shortly
after the instance stops or `spawn terminate`. (`spawn plugin remove` also stops
`tailscaled` on the instance.)

## Config

| Key | Required | Description |
|-----|----------|-------------|
| `tag` | yes | ACL tag assigned to the node (e.g. `tag:spore`); must be owned by the OAuth client's tag |

## Troubleshooting

- **`TS_API_CLIENT_ID and TS_API_CLIENT_SECRET must be set`** — you didn't
  `export` them in the shell running spawn (step 4).
- **`requested tags [tag:spore] are invalid or not permitted`** — the OAuth
  client's tag doesn't own `tag:spore`; fix `tagOwners` (step 2) or the tag you
  pass with `--config tag=`.
- **`curl and jq must be installed locally`** — `brew install jq`.
