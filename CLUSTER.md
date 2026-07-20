# The Slurm cluster

INSaFLU offloads heavy bioinformatics work (loading reference files and Pangolin lineages on startup,
processing uploaded samples) to a small [Slurm](https://slurm.schedmd.com/) cluster running alongside the
web app, rather than running it inside the web container itself. The cluster consists of:

- `slurmdbd` — the accounting daemon, talking directly to the `mysql` (MariaDB) accounting database.
- `slurmctld` — the controller/scheduler.
- `c1`/`c2` — two compute nodes (`slurmd`), where jobs actually run.

This starts automatically with `./up.sh` — there's nothing extra to run for normal use.

Everything below assumes all containers run on one machine. See [`MULTI_HOST.md`](MULTI_HOST.md) if you
want to run compute nodes on separate physical hardware instead, or
[`SWARM_VS_KUBERNETES.md`](SWARM_VS_KUBERNETES.md) if you want to distribute the whole stack (including the
database) across a cluster.

## Checking on the cluster

```bash
$ ./cluster-status.sh
```

This shows container health, `sinfo` (node status), and `squeue` (running/pending jobs). You can also run
these directly:

```bash
$ docker exec -it insaflu-ubuntu sinfo -N -l        # node status, CPUs/memory
$ docker exec -it insaflu-ubuntu scontrol show nodes
$ docker exec -it insaflu-ubuntu squeue              # running/pending jobs
$ docker exec -it insaflu-ubuntu sacct --format=JobID,JobName,State,ExitCode -a   # job history
```

## Adding compute nodes (e.g. c3, c4)

The cluster uses **static** nodes — `c1`/`c2` are plain, explicit services in `docker-compose.yml`, not
dynamically registered. (A previous attempt at dynamic node registration, where new nodes would
self-register by editing the shared Slurm config file, was built and then abandoned — self-editing a
shared config from multiple concurrently-starting containers turned out to be unreliable.) Adding a node
means extending this same static pattern:

1. **`components/slurm_master/configs/slurm/slurm.conf`** — the single canonical Slurm config, shared by
   every Slurm-aware container. Extend the node list:
   - `NodeName=c[1-2] CPUs=8 RealMemory=8192 State=UNKNOWN` → `NodeName=c[1-4] CPUs=8 RealMemory=8192 State=UNKNOWN`
   - `PartitionName=normal Default=yes Nodes=c[1-2] ...` → `Nodes=c[1-4]`

   (Use a separate `NodeName=c[3-4] ...` line instead if the new nodes need different CPU/RealMemory than
   `c1`/`c2` — a hostlist range like `c[1-4]` applies one CPUs/RealMemory value to the whole set.)

2. **`docker-compose.yml`** — add explicit `c3:`/`c4:` service blocks, copied from the existing `c1`/`c2`
   blocks, changing only `hostname:` and `container_name:`. No Dockerfile or entrypoint changes are needed —
   `slurmd` takes its node identity from the container's own hostname.

3. Bring the new nodes up and tell the controller about them:
   ```bash
   $ docker compose up -d c3 c4
   $ docker exec slurmctld scontrol reconfigure
   ```
   `scontrol reconfigure` reloads `slurm.conf` without a disruptive full restart — jobs already running or
   queued on `c1`/`c2` are untouched.

4. New nodes can briefly land in a `DOWN` state while they register. Because `slurm.conf` sets
   `ReturnToService=0`, a `DOWN` node **stays down** until manually resumed:
   ```bash
   $ docker exec slurmctld scontrol update NodeName=c3,c4 State=RESUME
   ```

5. Verify: `sinfo -N -l` / `scontrol show nodes` should show all nodes as `idle` with the right
   CPUs/RealMemory; `./cluster-status.sh` should report the correct node count.

## Resizing c1/c2's CPU/RealMemory

1. Edit the same `NodeName=c[1-2] CPUs=<new> RealMemory=<new> State=UNKNOWN` line in
   `components/slurm_master/configs/slurm/slurm.conf` (split into separate `NodeName=c1 ...` /
   `NodeName=c2 ...` lines if the two nodes need different values).

   This only changes what Slurm *believes* each node has — there are no Docker-level resource limits
   (`deploy.resources`/`mem_limit`/`cpus`) configured anywhere in this compose file today, so nothing
   currently stops a container from actually using more or less than its declared amount. Adding Docker-level
   enforcement to match is a reasonable idea, but is a separate change from a plain resize.

2. If jobs might currently be running on `c1`/`c2`, drain them first so the resize doesn't interrupt
   anything important:
   ```bash
   $ docker exec slurmctld scontrol update NodeName=c1,c2 State=DRAIN Reason="resizing"
   ```

3. Apply the change:
   ```bash
   $ docker exec slurmctld scontrol reconfigure
   $ docker compose restart c1 c2
   ```
   Restarting `slurmd` on `c1`/`c2` is needed so each node's own self-reported capacity matches the new
   config — this will interrupt anything *running* on them at that moment (pending jobs simply re-queue).

4. Resume if either node lands `DOWN` (same `ReturnToService=0` behavior as above):
   ```bash
   $ docker exec slurmctld scontrol update NodeName=c1,c2 State=RESUME
   ```

5. Verify with `sinfo -N -l` / `scontrol show nodes` (updated `CPUS`/`MEMORY` columns) and `squeue` (no
   unexpected job loss).
