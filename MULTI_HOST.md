# Running Slurm compute nodes on a separate machine

By default everything in this repo — the web app, database, and the whole Slurm cluster — runs on one
physical machine. This document covers what's needed to run some Slurm compute nodes (existing `c1`/`c2`,
or new `c3`/`c4`) on **separate hardware** instead, for more compute capacity. It does not cover
distributing the rest of the stack (web app/database) — that's a much bigger undertaking (effectively
Docker Swarm or Kubernetes, plus database HA) and isn't what this covers.

**This is a design reference, not a turnkey script.** The IP addresses below (`10.100.0.1`/`10.100.0.2`)
are placeholders — replace them with your actual VPN addresses. Nothing here has been run end-to-end
against a real second machine; treat it as a starting point and validate each step as you go.

## Why not Docker Swarm

Docker Swarm is the "native" way to run containers across multiple Docker hosts, but it means converting
this deployment to a Swarm stack file, adopting overlay networks and placement constraints, and a
`docker stack deploy` workflow that every existing script here (`up.sh`, `build.sh`, `stop.sh`,
`cluster-status.sh`) doesn't know about. It also needs a container registry to distribute images across
nodes (Swarm doesn't build images per-node the way `docker compose build` does) — this repo has none today.

Simpler and consistent with how this repo already prefers explicit static configuration over cleverness
(see `CLUSTER.md` on why an earlier dynamic node-registration system was abandoned): run a second, smaller
`docker compose` project on the remote machine, connected over a private VPN.

## The pieces

1. **Machine A** (existing): `db_insaflu`, `officer`, `mysql`, `slurmdbd`, `slurmctld`, `insaflu-ubuntu`,
   and optionally `c1`/`c2` if only new `c3`/`c4` are moving.
2. **Machine B** (new): its own `git clone` of this repo, its own `.env` (with the same `SLURM_TAG`/
   `IMAGE_TAG` as Machine A — Slurm requires every node to run the same version), and a small compose file
   (e.g. `docker-compose.remote-nodes.yml`) defining just the moved/new nodes, copy-pasted from the `c1`/`c2`
   pattern in the main `docker-compose.yml`.
3. **A private network between them.** [WireGuard](https://www.wireguard.com/) is the simplest option —
   self-hosted, minimal config, no third-party coordination service. Give each machine a static IP on the
   tunnel (e.g. Machine A `10.100.0.1`, Machine B `10.100.0.2`).
4. **Shared storage over NFS**, and **config/secrets kept in sync via git** — both detailed below.

## Shared storage: NFS

Machine A becomes the NFS server for whatever compute nodes on Machine B need to see; Machine B mounts
those exports as an NFS client.

**Must be shared** (this is what `c1`/`c2` mount today):
- `slurm_jobdir` → `/data` (the job working directory — this is how `sbatch` hands off work; without this
  shared, jobs can't actually run)
- `insaflu-software` → `/software` (the bioinformatics tools jobs execute)
- `insaflu-ubuntu-data` → `/insaflu_web/INSaFLU/media`
- `insaflu-ubuntu-static` → `/insaflu_web/INSaFLU/static_all`
- `insaflu-ubuntu-env` → `/insaflu_web/INSaFLU/env`
- `televir` → `/opt/televir`
- `var_log_insaflu` → `/var/log/insaFlu`
- `tmp_insaflu` → `/tmp/insaFlu`

**Can stay local to Machine B**: `var_log_slurm` — sharing it loses nothing, but skipping it just means
Machine B's own Slurm daemon logs aren't visible from Machine A without extra tooling.

Several of these (`slurm_jobdir`, `insaflu-software`, `var_log_insaflu`, `tmp_insaflu`) currently use
Docker's plain `local` volume driver, which doesn't pin them to a known host path the way the `local-persist`
volumes are pinned to `${BASE_PATH_DATA}` — worth converting them to `local-persist` on Machine A too,
purely so there's a known path to export over NFS.

Example: export the relevant `${BASE_PATH_DATA}/...` directories from Machine A via `/etc/exports`, then on
Machine B's compose file, define the same volume names using NFS instead of `local-persist`:

```yaml
volumes:
  slurm_jobdir:
    driver: local
    driver_opts:
      type: nfs
      o: addr=10.100.0.1,rw,nfsvers=4       # Machine A's WireGuard IP
      device: ":/exported/path/to/slurm_jobdir"
  # ...repeat for insaflu-software, insaflu-ubuntu-data, insaflu-ubuntu-static,
  #    insaflu-ubuntu-env, televir, var_log_insaflu, tmp_insaflu
```

`c3`/`c4` on Machine B then mount these exactly like `c1`/`c2` do today — no Dockerfile or entrypoint
changes needed either way.

## Config and secrets: kept in sync via git, not auto-synced

`components/slurm_master/configs/slurm/slurm.conf`, `cgroup.conf`, and
`components/slurm_master/configs/munge/munge.key` are already tracked in git, so Machine B's `git clone`
naturally carries identical copies of all three.

**The risk is drift afterward.** Each container's entrypoint only copies these files into place when the
container *starts* — not when the file changes on disk. So any time `slurm.conf`/`cgroup.conf`/`munge.key`
change on Machine A (adding a node, resizing CPU/RAM per `CLUSTER.md`, rotating the munge key), Machine B
needs to `git pull` and recreate its containers, or it silently runs on stale config — the same class of
problem `CLAUDE.md` documents from before `slurm.conf` was consolidated into one canonical copy, just
across machines instead of across directories this time.

There's no automated sync here by design (consistent with this repo's preference for explicit, manual
steps over hidden magic for a small deployment) — just a documented step:

```bash
# On Machine B, after any slurm.conf/cgroup.conf/munge.key change on Machine A:
git pull
docker compose -f docker-compose.remote-nodes.yml up -d --force-recreate c3 c4
```

A munge key rotation is the highest-stakes version of this — if Machine B's key falls out of sync with
Machine A's, Slurm authentication breaks across the whole cluster, not just on one host.

## `slurm.conf` changes

On Machine A's canonical `components/slurm_master/configs/slurm/slurm.conf` (carried to Machine B via git):

1. `SlurmctldHost=slurmctld` → `SlurmctldHost=slurmctld(10.100.0.1)` — Slurm's documented `Host(Addr)`
   syntax. Needed because Machine B can't resolve `slurmctld` as a Docker-internal DNS name the way
   containers on the same host can.
2. Extend the node list per `CLUSTER.md`'s existing add-a-node steps, but add an explicit `NodeAddr` for
   any node that isn't reachable by hostname (i.e. anything on Machine B), since cross-host name resolution
   doesn't work here the way Docker's embedded DNS does on one host:
   ```
   NodeName=c3 NodeAddr=10.100.0.2 CPUs=8 RealMemory=8192 State=UNKNOWN
   ```
   (repeat per remote node; use Machine B's WireGuard IP).
3. `PartitionName=normal ... Nodes=c[1-2] ...` → extend `Nodes=` to include the new/moved node names, same
   as any other node addition.

## `docker-compose.yml` port changes

Today `slurmdbd`/`slurmctld` use `expose:` (Docker-internal only — not reachable outside the host at all).
For Machine B to reach them, they need to be published, but **only onto the VPN interface**, never onto
a public one:

```yaml
# Machine A's docker-compose.yml
slurmdbd:
  ports:
    - "10.100.0.1:6819:6819"   # was: expose: ["6819"]
slurmctld:
  ports:
    - "10.100.0.1:6817:6817"   # was: expose: ["6817"]
```

Same pattern for the moved nodes' port `6818` in Machine B's compose file, bound to Machine B's WireGuard IP.

## Security

Slurm and munge are not designed to be hardened against exposure to an arbitrary network — munge trusts
its transport channel, and Slurm's RPC protocol assumes a trusted internal network. The WireGuard tunnel
*is* the security boundary here, not optional extra hardening:

- Always bind published ports to the VPN interface IP specifically (`10.100.0.1:6817:6817`), never to
  `0.0.0.0`.
- Firewall both machines to block 6817/6818/6819 on any public-facing interface as defense in depth, in
  case a port binding is ever accidentally widened.
