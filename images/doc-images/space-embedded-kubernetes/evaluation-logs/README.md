# Cyclone V k3s evaluation logs

These logs come from the same method as the Raspberry Pi evaluation in Space-Age DevOps
(`vmstat -a -SM -w -t 1 30`, plotted with
[vmstat-visualizer](https://github.com/kosmoedge/vmstat-visualizer)). This time it runs on the
Cyclone V SoC (`cyclone5-37`): dual-core Cortex-A9 at 800 MHz, 1 GB DDR3, Yocto kirkstone, and
k3s v1.22.6 as the cluster's only server. All captures were taken on 2026-10-19. Timestamps are in
UTC.

The graphs are in [`../evaluation-graphs`](../evaluation-graphs), with one folder per scenario plus
`comparisons/`.

## Collector

The Cyclone V image is BusyBox-only and has no `procps` `vmstat`.
[`vmstat-lite.sh`](./vmstat-lite.sh) is a single BusyBox `awk` process that reads `/proc/stat`,
`/proc/vmstat`, `/proc/meminfo` and `/proc/uptime`. It prints the same columns and units as
`vmstat -a -SM -w -t`. It also prints a `gu` column (always 0), because vmstat-visualizer reads
columns by position and expects it. The script is streamed over SSH, so nothing is installed on the
board:

```bash
ssh root@<cyclonev> 'sh -s 1 30' < vmstat-lite.sh > cyclonev_<scenario>.log
vmstat-visualizer visualize cyclonev_<scenario>.log -o cyclonev_<scenario>
vmstat-visualizer compare a.log b.log -m all -o a_vs_b
```

As with `vmstat`, the first data row is the average since boot. Memory values are in MB. The
graphs label the axis "KB", but the values are MB because of `-S M`.

## Scenarios

| Log | Scenario |
|---|---|
| `cyclonev_baseline.log` | No k3s: `systemctl stop k3s containerd` + `k3s-killall.sh`, 0 k3s/containerd processes, 30 s settle |
| `cyclonev_k3s_no_workloads.log` | k3s server + default add-ons (coredns, traefik, metrics-server, local-path); all `default` namespace workloads scaled to 0 |
| `cyclonev_k3s_current.log` | Cluster as deployed: fpga-power-saver/scaler, tiered workers, nmf-clock, demo-imaging |
| `cyclonev_k3s_settled.log` | Same workloads, 60 s after every pod was Ready again following the k3s restart |

[`cyclonev_baseline_run_notes.txt`](./cyclonev_baseline_run_notes.txt) holds the baseline run's
events, the process list during the baseline, and the recovery timeline after k3s restarted.

## Summary

These are means over 29 samples (the since-boot row is excluded). Ranges are shown in parentheses.

| Scenario | Samples | free MB | active MB | us % | sy % | id % | in/s | cs/s |
|---|---|---|---|---|---|---|---|---|
| `baseline` | 29 | 600 (600–600) | 212 | 0 | 0 | 99 (87–100) | 269 | 68 |
| `k3s_no_workloads` | 29 | 74 (73–77) | 377 | 27 | 4 | 69 (14–96) | 1748 | 3470 |
| `k3s_current` | 29 | 70 (57–76) | 197 | 40 | 8 | 51 (4–74) | 2209 | 4178 |
| `k3s_settled` | 29 | 13 (12–14) | 373 | 40 | 8 | 51 (4–86) | 2256 | 4193 |

- **k3s itself is the main cost.** The control plane and add-ons take free memory from about 600 MB
  to about 74 MB. They also cost about 30 percentage points of CPU idle time. Interrupts rise about
  6.5× and context switches about 50×, before any mission workload runs.
- **The workloads add a little more.** In this deployment they cost about another 18 points of CPU
  idle time and change free memory only slightly (74 → 70 MB).
- **The first minutes after a k3s restart are the tightest.** Free memory drops to about 13 MB while
  the pods start again. Recovery takes several minutes, mostly kube-controller-manager start-up (see
  the run notes).
