# Changelog

All notable changes to the vote-poll observability configuration will be documented in this file.

## [2026-08-04]

### Added
- **Wrapper Chart for Loki:** Created `k8s-helm-charts/loki-monitoring` wrapper chart referencing `loki-stack` (v2.10.3) as a dependency to control log-aggregation resources.
- **Loki Version Upgrade:** Upgraded Loki image version tag to `2.9.3` in the wrapper values to support modern LogQL features (like `| drop`) and resolve compatibility syntax errors with Grafana 11.1.0.
- **Resource Constraints Adjustment:** Increased Loki's CPU limits to `1000m` and memory limits to `512Mi` to prevent startup CPU throttling and avoid liveness/readiness probe timeouts.
- **Log Parsing Pipeline:** Added `docker: {}` pipeline stage under `promtail.config.snippets.pipelineStages` in the wrapper chart values. This automatically extracts raw application logs from the Docker JSON log structure wrapper (e.g. mapping `log` to the log output, setting custom timestamps from `time`, and exposing `stream` as a query label).

### Changed
- **Grafana Integration:** Registered Loki as an automatic Grafana DataSource in `k8s-helm-charts/grafana-monitoring/values.yaml` pointing to `http://loki:3100`.
- **Documentation:** Updated the deployment instructions under `ms/README.md` to detail dependency building and installation commands for the custom `loki-monitoring` chart.

### Removed
- **Standalone Configuration:** Removed the deprecated `k8s-helm-charts/loki-values.yaml` configuration file.
