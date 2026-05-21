# Writing a spore-host plugin

A plugin is a single `plugin.yaml` file that declares what commands to run on the EC2 instance.

## Minimal example

```yaml
name: my-plugin
version: v1.0.0
description: "Does something useful"
author: yourname
license: MIT

install:
  - run: |
      curl -fsSL https://example.com/install.sh | bash

configure:
  - run: |
      echo "configured"
```

## Spec fields

| Field | Required | Description |
|-------|----------|-------------|
| `name` | yes | Plugin identifier (kebab-case) |
| `version` | yes | Semver tag |
| `description` | yes | One-line description |
| `author` | yes | Your GitHub username or org |
| `license` | yes | SPDX identifier |
| `install` | yes | Steps run once on first install |
| `configure` | no | Steps run on each instance start |
| `env` | no | Environment variables to set |
| `ports` | no | Ports to open in security group |

## Submitting

1. Fork this repo
2. Create `plugins/<your-plugin-name>/plugin.yaml`
3. Open a pull request
