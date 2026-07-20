# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

## What this repository is

This is the **Docker deployment/infrastructure** for INSaFLU (bioinformatics platform for viral genomic
surveillance, e.g. influenza/SARS-CoV-2). It does not contain the INSaFLU Django application source code
itself — that is fetched/installed inside the `insaflu-ubuntu` image at build time. This repo defines:

- The multi-container topology (`docker-compose.yml`) that wires together the web app, database, a
  Slurm cluster used to run bioinformatics jobs, and an ML model-serving stack.
- Dockerfiles and install scripts for each component under `components/`.
- Operational shell scripts (`up.sh`, `stop.sh`, `build.sh`, etc.) used to bring the stack up/down.

## Common commands

```bash
# First-time setup: copy and edit environment config
cp .env_temp .env
vi .env                 # set BASE_PATH_DATA, APP_PORT, TIMEZONE, SLURM_TAG, IMAGE_TAG, etc.

# Build all images (reads .env)
./build.sh               # docker compose build

# Start the stack (creates data dirs under BASE_PATH_DATA, copies insaflu.env, then `docker compose up`)
./up.sh

# Stop the stack
./stop.sh                # docker compose stop

# Inspect the Slurm cluster (nodes, running jobs, container health)
./cluster-status.sh

# Create the first INSaFLU user (run once the stack is up)
docker exec -it insaflu-server create-user
```

Note: `docker compose up insaflu-ubuntu` (what `up.sh` runs) also brings up the static `c1`/`c2` compute
nodes automatically, since they're `depends_on` dependencies of `insaflu-ubuntu` — there is no separate
dynamic node scaling in this repo.

TELEVIR is **not** built/run from this repo's `docker-compose.yml` anymore — it was outsourced to its own
project ([SantosJGND/TELEVIR](https://github.com/SantosJGND/TELEVIR)); see README for the current
install-by-cloning-that-repo instructions. `up_televir.sh` and the `TELEVIR_IMAGE`/`TELEVIR_BASE_PATH_DATA`/
`TELEVIR_PORT` vars in `.env_temp` are leftovers from the old in-repo TELEVIR service and no longer
correspond to anything in `docker-compose.yml` (there is no `televir-server` service) — treat them as stale
unless/until they're cleaned up. The `televir` named volume itself is still real and still mounted into
`c1`/`c2`/`insaflu-ubuntu` at `/opt/televir`, since the externally-installed TELEVIR shares that data with
the web app and compute nodes.

### `docker exec -it insaflu-server <command>` operational commands

Defined as scripts in `components/insaflu-ubuntu/commands/` and installed into the image's PATH:

`create-user`, `list-all-users`, `update-password`, `remove-fastq-files`, `unlock-upload-files`,
`restart-apache`, `upload-reference-dbs`, `update-nextstrain_builds`, `update-insaflu`,
`test-email-server`, `confirm-email-account`, `update-tbl2asn`, `upload-samples`,
`update_televir_references`. `register_televir_refs.sh`/`load_defaults.sh` are submitted via `sbatch`
from the `insaflu-ubuntu` entrypoint rather than invoked directly.

Runtime app configuration lives in `components/insaflu-ubuntu/configs/insaflu.env`, which is copied to
the persisted volume at `${BASE_PATH_DATA}/insaflu/env/insaflu.env` on first `up.sh` run (subsequent edits
should be made in the persisted copy, mounted at `/insaflu_web/INSaFLU/env/insaflu.env` inside the
container — see README's "Change variables in your local environment").

There is no test suite, linter, or build step for application code in this repo — validation is done by
building images and exercising the running stack (`build.sh` then `up.sh`, checked via `cluster-status.sh`
and the web UI on `127.0.0.1:${APP_PORT}`).

## Architecture

### Compose services and boot order

`docker-compose.yml` defines two logical clusters on two docker networks (`insaflu_ubuntu_net` for the app,
`slurm-network` for Slurm-internal traffic; the Slurm node containers join both), plus a standalone ML
serving stack:

1. **`db_insaflu`** — Postgres+PostGIS (`components/postgres_postgis`), the INSaFLU application database.
2. **`officer`** — `funkyfuture/deck-chores`, a cron-like sidecar that runs scheduled commands inside other
   containers via labels (e.g. the `insaflu-ubuntu` service has a `deck-chores.update-pangolin` label that
   runs `/software/update_pangolin.sh` hourly).
3. **Slurm cluster**, used to submit/run heavy bioinformatics jobs off the web container:
   - `mysql` (MariaDB, pinned version e.g. `mariadb:12.3.2`) — Slurm accounting DB.
   - `slurmdbd` → `slurmctld` → `c1`/`c2` (slurmd compute nodes) — strict startup dependency chain, each
     waiting on the previous daemon's TCP port before starting (see each `entrypoint.sh`).
   - **Accounting storage is split by role, on purpose**: `slurmdbd.conf` (only ever read by the `slurmdbd`
     daemon itself) has `StorageType=accounting_storage/mysql` / `StorageHost=mysql` and the real MariaDB
     password, and is mounted *only* into the `slurmdbd` container (`components/slurm_master/configs/slurmdbd/`).
     Every other Slurm-aware container (`slurmctld`, `c1`, `c2`, `insaflu-ubuntu`) instead gets the shared
     `slurm.conf`, whose `AccountingStorageType=accounting_storage/slurmdbd` / `AccountingStorageHost=slurmdbd`
     tell them to route accounting through the `slurmdbd` daemon over RPC rather than talk to MariaDB
     directly — so the DB password is never copied anywhere it isn't needed.
   - `slurm.conf`/`cgroup.conf` live in **one canonical directory**, `components/slurm_master/configs/slurm/`,
     bind-mounted read-only into all five Slurm-aware services. Keep it that way — this used to be three
     independently-edited copies (one each for `slurm_master`, `slurm_nodes`, `insaflu-ubuntu`) and they drifted
     out of sync (missing `NodeName`/`PartitionName`, missing cgroup directives) badly enough to break the
     cluster. Slurm's own convention is that `slurm.conf` should be identical across the whole cluster.
   - All Slurm containers share a **munge key** (mounted read-only from
     `components/slurm_master/configs/munge/munge.key`) — this must stay consistent across master, node, and
     web images since Slurm authentication depends on identical munge keys and matching UID/GID for the
     shared `slurm` user (uid 990) and `flu_user` app user (uid 1000) across all containers. Every
     Slurm-aware container runs its **own independent `munged`** (not a shared socket) — each entrypoint's
     `move_slurm_key`/`move_munge_key` function force-copies the real key from `/run/secrets/munge.key` over
     whatever the `slurm-runtime` base image baked in at build time (it generates its own throwaway key via
     `mungekey -cf`), so don't reintroduce a conditional "only copy if missing" guard there.
   - Compute nodes (`c1`, `c2`) additionally mount the INSaFLU media/static/software/env volumes so that
     jobs dispatched via `sbatch` can read/write the same files the web app sees.
4. **`insaflu-ubuntu`** — the main Django web app container (built from a full Ubuntu 20.04 image with
   conda + a large stack of bioinformatics tools; see `components/insaflu-ubuntu/software/`). Starts only
   after Postgres is healthy, `officer` is healthy, and the Slurm cluster (`slurmctld`, `c1`, `c2`) has
   started. Runs with `command: ["init_all"]`, whose entrypoint logic (`components/insaflu-ubuntu/entrypoint.sh`):
   - installs the munge key/Slurm config from mounted secrets, starts its own `munged`,
   - waits for Postgres/PostGIS to be ready,
   - re-links the persisted `insaflu.env` to Django's `.env`,
   - runs `collectstatic`, `makemigrations`, `migrate`,
   - fixes ownership/permissions on media, logs, static dirs,
   - submits `load_defaults.sh` as a Slurm job (`sbatch`) to load default reference files/settings and
     Pangolin lineages, and (if TELEVIR's `utility_docker.db` is present) submits `register_televir_refs.sh`,
   - starts Apache and tails forever.
5. **`mlflow` + `ml_app`** — a standalone ML model-serving stack (`components/ml_api/`), unrelated to the
   Slurm cluster. `mlflow` is the stock MLflow tracking server/model registry (SQLite backend, local
   artifact store). `ml_app` is a FastAPI service that loads pickled model bundles (recall-cutoff and
   composition-stop-traversal predictors, mainly for TELEVIR classification thresholds) from
   `components/ml_api/models/` or the MLflow registry and serves `/predict_*` endpoints on port 8000. See
   `components/ml_api/README.md` for the training/deployment workflow and endpoint examples.

### Scaling the Slurm cluster

`c1`/`c2` are static, explicit services in `docker-compose.yml` — not dynamically registered. A prior
attempt at dynamic node registration (nodes self-editing the shared `slurm.conf` via `sed`, then
`scontrol reconfigure`) was built and abandoned as too racy; don't reintroduce that pattern (e.g. via YAML
anchors + a node template + `docker compose --scale`) without addressing why it failed before. See
[`CLUSTER.md`](CLUSTER.md) for the actual procedure to add nodes or resize `c1`/`c2`.

### Image layering

- `components/slurm_master/Dockerfile` builds a two-stage image: stage 1 compiles Slurm from source
  (version pinned by `SLURM_TAG`) on Ubuntu 22.04, stage 2 (`slurm-runtime:<tag>`) is a slim runtime
  image with the compiled Slurm binaries, `munge`, `gosu`, and the shared `slurm`/`munge`/`flu_user` system
  accounts. This runtime image is the base (`FROM slurm-runtime:${SLURM_TAG}`) for both
  `components/slurm_nodes/Dockerfile` (adds compute-node software/config) and
  `components/insaflu-ubuntu/Dockerfile` (adds the full INSaFLU web app on top of the Slurm client tooling)
  — so `slurm_master` must be built (or pulled) before the other two images. `docker compose build` handles
  this ordering automatically since it's the `context: components/slurm_master/.` build. The base image tag
  is driven by a global `ARG SLURM_TAG` (defaulted to match compose's own `${SLURM_TAG:-25.05.3}` fallback)
  — don't hardcode this tag in the `FROM` line, or it'll silently drift out of sync with whatever tag
  `docker compose build` actually produces and break the build.
- `components/insaflu-ubuntu/Dockerfile` install order matters: system packages → Apache → miniconda →
  bioinformatics software (`install_software.sh`, installs everything under `software/`, e.g. snippy, IRMA,
  nextstrain, pangolin, medaka, flye, raven, prokka, snpEff, EMBOSS, mauve, trimmomatic, aln2pheno, flumut)
  → website dependencies → the Django website itself → Slurm client entrypoint wiring.
- `components/ml_api/Dockerfile` is a separate, much smaller Python/FastAPI image — not layered on
  `slurm-runtime` at all, since it has nothing to do with the Slurm cluster.

### Configuring what TELEVIR installs

TELEVIR now lives entirely in its own repo and is installed by cloning it and running its own Docker build
against this repo's shared data volume — see the "Change TELEVIR software install configuration" section of
README.md for the exact commands. What software/databases it installs (reference DBs, host genomes,
classifiers, assemblers) is configured over there, not in this repo.

### Environment variables (`.env`, copy from `.env_temp`)

Key variables: `BASE_PATH_DATA` (host path where all persisted data lives, bind-mounted directly into each
service — no volume plugin involved; `docker-compose.yml`'s stateful volumes are plain
`${BASE_PATH_DATA}/...` bind mounts), `APP_PORT` (INSaFLU web UI port), `TIMEZONE`, `USERNAME_IMAGE`/`IMAGE`/`IMAGE_TAG` (image
naming), `SLURM_TAG` (Slurm version built from source — must match across `slurm_master`/`slurm_nodes`,
and must correspond to a real tag/branch in `SchedMD/slurm` on GitHub). `TELEVIR_IMAGE`/
`TELEVIR_BASE_PATH_DATA`/`TELEVIR_PORT` are vestigial (see the TELEVIR note above) — safe to ignore.
