# cloudwatch-agent

Installs and starts the **Amazon CloudWatch agent** on your spawn instance to
publish host metrics (CPU, memory, disk) and, optionally, a log file to
CloudWatch Logs.

## ⚠️ Precondition: the instance IAM role must have CloudWatch access

The agent ships metrics/logs using the **instance's IAM role**. A plugin runs
post-launch and **cannot** set the instance profile — launch the instance with a
role granting `cloudwatch:PutMetricData` (and, if you use `log_file`,
`logs:CreateLogGroup`/`CreateLogStream`/`PutLogEvents`). The AWS-managed
`CloudWatchAgentServerPolicy` covers this.

## How it works

The plugin installs `amazon-cloudwatch-agent` (from the AL2023 repos, or the
official package elsewhere), writes a config publishing CPU/mem/disk under your
metrics namespace, optionally adds a log-file tail, and starts the agent via its
control script. A health check confirms the agent reports `running`.

## Config

| Key | Default | Description |
|-----|---------|-------------|
| `metrics_namespace` | `CWAgent` | CloudWatch metrics namespace. |
| `collection_interval` | `60` | Metrics collection interval (seconds). |
| `log_file` | *(none)* | Optional log file path to ship to CloudWatch Logs. |
| `log_group` | `/spore/instance` | Log group for `log_file`. |

## Install

```bash
spawn plugin install cloudwatch-agent --instance <id> \
  --config log_file=/var/log/myapp.log --config log_group=/spore/myapp
```

## Notes

- spawn's autoscaler reads the **`CWAgent`** namespace — keep the default
  namespace if you want autoscaling to see these metrics.
- Metrics/logs to CloudWatch incur AWS charges; a 60s interval on a few metrics
  is inexpensive but not free.
- spawn's own telemetry goes through `spored`/Prometheus independently — this
  plugin is for exporting to CloudWatch specifically (dashboards, alarms,
  autoscaling).
