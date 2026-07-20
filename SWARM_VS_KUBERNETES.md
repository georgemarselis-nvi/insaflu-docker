# Distributing the whole stack: Docker Swarm vs. Kubernetes

See [`MULTI_HOST.md`](MULTI_HOST.md) for the narrower case of moving just Slurm compute nodes to a second
known machine — that stayed on plain `docker compose` + WireGuard deliberately, since that scope didn't
need a real orchestrator. This document covers the qualitatively different problem: distributing the
**entire** stack, including `db_insaflu`/`mysql`, across an arbitrary number of nodes.

**This is a design reference, not a turnkey script**, same as `MULTI_HOST.md` — nothing here has been run
against a real cluster. Treat it as a starting point, and expect to validate every step.

## Why this is different from `MULTI_HOST.md`

`MULTI_HOST.md` had two known machines and two known roles (app/DB/control-plane vs. compute nodes) — a
fixed topology, solvable with static IPs, NFS, and keeping a git checkout in sync. Here the goal is "any
service can run on any of N nodes" — that's not a bigger version of the same problem, it's the actual
definition of what an orchestrator is for: dynamic placement decisions, rescheduling on node failure,
cluster-wide service discovery instead of Docker's single-host embedded DNS, rolling updates across nodes.
This is the point where "just run more `docker compose` projects" genuinely stops working.

## Cross-cutting concerns (apply regardless of which orchestrator you pick)

### Distributing ≠ highly available

`db_insaflu` (Postgres+PostGIS) and `mysql` (MariaDB, Slurm's accounting DB) are single-instance services
today. An orchestrator scheduling that one instance onto "some available node" is *relocatable placement*,
not replication — if the node dies, the scheduler restarts the container elsewhere, but there's a gap, and
if storage isn't equally available on every node it may not come back at all. Real database HA needs
deliberate, separate work: [Patroni](https://patroni.readthedocs.io/) (+ etcd/Consul) for Postgres, Galera
or built-in group replication for MariaDB. Don't let "distribute the stack" quietly turn into an implicit
promise of HA — pick one explicitly:
- Accept single-instance-pinned-to-a-node as the near-term target (what this document recommends), or
- Scope real DB HA as its own, later project.

### Storage

Today's volumes are all node-local: `local-persist` (pinned host paths under `${BASE_PATH_DATA}`) and
Docker's plain `local` driver (opaque host storage). Both break silently once a container can be
rescheduled to a different node — the same "which container's image populates the empty named volume
first" fragility already known from this session's `insaflu-software` volume bug, now happening across an
entire cluster instead of one host.

Two real fixes:
- **Distributed storage**: [Longhorn](https://longhorn.io/) or Ceph (via Rook) for Kubernetes, giving a
  `StorageClass` that any node can attach to. Swarm's native story here is weaker — typically an external
  volume plugin, or falling back to NFS (same pattern as `MULTI_HOST.md`).
- **Node-pinning**: keep stateful services tied to specific nodes with node-local storage — simpler, but
  gives up some of the "distribute freely" benefit for exactly the services (databases, Slurm's master
  pieces) where you'd want that benefit least anyway.

Recommendation: node-pin the stateful pieces + NFS initially; only invest in real distributed storage
(Longhorn) if/when Kubernetes is adopted and the team wants to go further than that.

### Slurm-in-a-scheduler tension

This is specific to this stack and easy to miss: `slurm.conf` bakes in `SlurmctldHost=slurmctld`,
`NodeName=c[1-2] ...`, `PartitionName=... Nodes=c[1-2] ...` — all assuming *stable* names/addresses,
currently resolved via Docker's single-host embedded bridge DNS. If an orchestrator freely reschedules
`slurmctld`/`c1`/`c2` to different underlying nodes with different IPs, Slurm's own config goes stale —
the same problem `MULTI_HOST.md` solved with a static `NodeAddr=`, but here a static IP doesn't exist if
the scheduler can move the container around at will.

The fix is to **pin Slurm's own pieces to stable identities even while the surrounding app tier floats
freely** — not every part of "the stack" benefits equally from free rescheduling:
- **Swarm**: placement constraints (`node.labels.slurm==master`) keeping `slurmctld`/`c1`/`c2` on the same
  physical node(s), so their Docker-DNS-based identity stays stable.
- **Kubernetes**: a `StatefulSet` + headless `Service` for the Slurm pieces gives each pod a stable DNS
  name (`slurmctld-0.slurm-headless.default.svc.cluster.local`) regardless of which node it's scheduled
  to — a genuinely better fit for Slurm's stable-identity assumption than Swarm's placement-constraint
  workaround, worth noting even though the overall recommendation below goes the other way.

Only the genuinely stateless/horizontally-scalable tier — arguably just `insaflu-ubuntu`'s web/Apache
front and `ml_app` — actually benefits from being freely schedulable.

### Secrets

`munge.key` and `insaflu.env` are plain bind-mounted files today (`munge.key` checked into git, force-copied
at entrypoint time). Both orchestrators offer a first-class alternative: `docker secret` for Swarm, a
`Secret` object for Kubernetes. Concretely, Swarm secrets mount at `/run/secrets/<name>` by default —
exactly the path this repo's entrypoints already expect for `munge.key`, making it a low-friction swap.
Treat this as a natural upgrade to do during migration, not a blocker.

### Image registry (new infrastructure, either option)

There is no container registry anywhere in this repo's tooling today — `build.sh` just runs
`docker compose build`, producing local-only image tags, and `MULTI_HOST.md`'s approach was literally
"clone the repo and build locally on the second machine too." That doesn't scale once any node might run
any service on demand — both Swarm and Kubernetes need images pullable from a shared location before
scheduling can work at all: a self-hosted registry (`registry:2`), GHCR, or a private Docker Hub repo.
Budget for this as new operational surface (a build/push step, credentials, somewhere to run it)
regardless of which orchestrator you pick.

### `officer` (deck-chores) needs redesigning, not relocating

`officer` works today by mounting the host's `/var/run/docker.sock` and driving sibling containers via
`deck-chores.*` Docker labels (e.g. `insaflu-ubuntu`'s hourly Pangolin update). That pattern only sees
containers on *its own node's* Docker daemon — labels on a container scheduled to a different node are
invisible to it. This isn't a "just move the socket mount" fix; it needs an actual different mechanism:
- **Kubernetes**: a `CronJob` that runs the update via `kubectl exec` (or equivalent) targeting the right
  pod by label selector, independent of which node it landed on.
- **Simpler, either orchestrator**: retire the sidecar pattern entirely and move the one real recurring
  task (`update_pangolin.sh`) into the target container's own crontab — deck-chores' generality isn't
  actually needed for a single scheduled job.

## Option A: Docker Swarm

What's concretely needed:
- Convert `docker-compose.yml` into a Swarm-deployable stack file — mostly compose-compatible, plus
  `deploy:` keys (`replicas`, `placement.constraints`, `restart_policy`, `resources`). Drop `build:` blocks
  (Swarm doesn't build — needs pre-built, pushed images from the new registry) and `container_name:`
  (Swarm manages naming across replicas/nodes).
- `docker swarm init` on a manager node, `docker swarm join --token ...` on each worker.
- Replace both `bridge` networks (`insaflu_ubuntu_net`, `slurm-network`) with `overlay` driver networks —
  `bridge` doesn't span hosts at all.
- Placement constraints for the stateful/Slurm pieces:
  ```yaml
  db_insaflu:
    deploy:
      placement:
        constraints:
          - node.labels.role == db
  slurmctld:
    deploy:
      placement:
        constraints:
          - node.labels.role == slurm-master
  ```
- `docker secret create munge_key ./components/slurm_master/configs/munge/munge.key`, referenced via
  `secrets:` in the stack file.
- The registry from the cross-cutting section above.

Realistic survival estimate: most service definitions, volume-mount lists, and entrypoint/command logic
carry over close to as-is — a Swarm stack file is a compose-file superset. What needs real rework: every
`build:` block, `container_name:`, both networks (bridge → overlay), placement for stateful/Slurm pieces,
and `depends_on` reliability across nodes (Swarm doesn't wait on health conditions across hosts the way
single-host `docker compose` does — lean on the TCP-port wait loops several entrypoints already have).

Worth being honest about: `up.sh`/`build.sh`/`stop.sh`/`cluster-status.sh` all assume plain
`docker compose` today and would need rewriting around `docker stack deploy`/`docker service` — the same
point that argued *against* Swarm in `MULTI_HOST.md`. Here it's outweighed because, unlike the Slurm-only
case, an orchestrator is actually required to solve the stated problem.

## Option B: Kubernetes

What's concretely needed:
- `Deployment` for the genuinely stateless-ish pieces (a split-out web/Apache tier, `ml_app`, `mlflow`).
- `StatefulSet` (+ a **headless** `Service`, `clusterIP: None`) for `db_insaflu`, `mysql`, `slurmctld`,
  `c1`/`c2` — stable per-pod identity and a stable storage claim per replica.
- `PersistentVolumeClaim`s backed by a real `StorageClass` (Longhorn/Ceph-Rook self-hosted, or a cloud
  provider's block storage) — replaces `local-persist`/`local` volumes.
- `ConfigMap` for `slurm.conf`/`cgroup.conf` (keeps the "one canonical copy" property this session already
  established, just as a Kubernetes object instead of a bind-mounted directory).
- `Secret` for `munge.key`/`insaflu.env`.
- `Ingress` (needs an ingress controller, e.g. ingress-nginx) or a `NodePort`/`LoadBalancer` `Service` for
  the web app's port 80.

`kompose convert docker-compose.yml` is a legitimate rough starting point for a first draft — but it will
**not** handle: `privileged: true` on `c1`/`c2` (needs a manual `securityContext.privileged: true`, and
possibly an admission-controller carve-out), the cgroup v2/no-systemd assumptions baked into
`cgroup.conf`, or the StatefulSet + headless-Service stable-identity setup Slurm needs. All of that is
manual, Slurm-aware follow-up work after `kompose` gets you a first draft.

Illustrative (not exhaustive) skeleton for the Slurm controller:
```yaml
apiVersion: apps/v1
kind: StatefulSet
metadata:
  name: slurmctld
spec:
  serviceName: slurm-headless
  replicas: 1
  selector:
    matchLabels: {app: slurmctld}
  template:
    metadata:
      labels: {app: slurmctld}
    spec:
      containers:
        - name: slurmctld
          image: registry.example.org/slurm-runtime:25.05.3
          command: ["slurmctld"]
          volumeMounts:
            - {name: slurm-config, mountPath: /run/secrets/slurm, readOnly: true}
            - {name: munge-key, mountPath: /run/secrets/munge.key, subPath: munge.key}
  volumeClaimTemplates:
    - metadata: {name: slurm-jobdir}
      spec: {accessModes: ["ReadWriteMany"], storageClassName: longhorn, resources: {requests: {storage: 50Gi}}}
```

Bigger operational surface than Swarm either way: a real cluster (control plane + nodes), a CNI plugin, an
ingress controller, and a storage provisioner. **k3s** (single binary, lightweight) is worth naming
explicitly as the option for a small team, versus full kubeadm-based Kubernetes.

## Recommendation: Docker Swarm

This repo has already shown (in `MULTI_HOST.md`) a preference for the smallest operational leap that
solves the actual problem over adopting general-purpose orchestration machinery. The calculus is different
here than for the Slurm-only case — "any service on any node" genuinely requires an orchestrator, it's not
optional — but between the two, **Docker Swarm** is the better fit:

- It's the closest to the compose-file mental model already in use — a Swarm stack file is a superset of
  `docker-compose.yml`, not a rewrite into a different manifest format.
- No separate control-plane software to install and keep patched — it reuses the same Docker Engine
  already running everywhere (`docker swarm init`/`join` is built into `docker`, unlike Kubernetes even in
  its lightest form).
- It stays inside the existing shell-script-and-`docker`-CLI idiom (`docker stack deploy`,
  `docker service ls`) rather than adopting `kubectl` and a whole separate YAML-manifest ecosystem.
- Swarm's weaker native storage/HA story matters less than it first appears: per the "distributing ≠ HA"
  point above, *neither* option gives real database HA for free — so Kubernetes' stronger storage
  ecosystem (Longhorn/Ceph) isn't buying as much unless the team is also separately investing in
  Patroni/Galera.

**Caveat honestly**: if the real end goal is eventually true database HA, fine-grained autoscaling, or a
broader multi-team platform, Kubernetes' ecosystem (Postgres/MariaDB operators, HPA, richer RBAC) is the
better long-term bet. Recommending Swarm now is a "smallest leap that solves today's problem" choice, not
a claim that Swarm is better in general — revisit if/when real HA or autoscaling becomes an actual
requirement.

## Migration path

Phased — this is not a small change:

1. **Prep** (no orchestrator yet): stand up the container registry; finish converting the remaining plain-
   `local`-driver volumes to `local-persist` (continuing a pattern already partly in place); decide and
   document which physical node(s) will hold which role (db, Slurm master, general app tier).
2. **Redesign `officer`** on the current single-host setup first, independent of the cluster cutover, so
   it's validated before adding cross-node complexity on top.
3. **Swarm bootstrap**: `docker swarm init` on the first machine (as manager), join additional machines as
   workers; set up the overlay networks; validate basic cross-node connectivity with a throwaway service
   before touching the real stack.
4. **Convert the stack incrementally**, lowest-risk first: `mlflow`/`ml_app` → `db_insaflu`/`mysql`
   (pinned, no HA yet, per the caveat above) → the Slurm chain (`slurmdbd` → `slurmctld` → `c1`/`c2`,
   pinned/stable per the Slurm-in-a-scheduler section) → `insaflu-ubuntu`.
5. **Secrets migration** alongside the Slurm-chain step — the natural point to move `munge.key` to
   `docker secret`.
6. **Validate**: adapt `cluster-status.sh`'s checks to `docker service ps`/`docker stack ps`; confirm
   `sinfo`/`squeue` and `sbatch` job submission from `insaflu-ubuntu` still work end-to-end across nodes.
7. **Real database HA** (Patroni/Galera) — explicitly scoped as separate, later work, not part of this
   migration.
