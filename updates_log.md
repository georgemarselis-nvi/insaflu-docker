# INSaFLU Docker — Git Activity Summary

**Period:** Jun 2024 – May 2026  
**Contributors:** SantosJGND (299 commits), dsobral/Daniel Sobral (9 commits)

---

## Phase 1: CentOS → Ubuntu Migration (Jun–Dec 2024)

- Migrated base OS from CentOS/RockyLinux to Ubuntu 22.04
- Simplified Dockerfiles, entrypoints, and install scripts for Ubuntu
- Updated software stack: Medaka 2.0, SPAdes 4.0, FreeBayes 1.3.6, MAFFT
- Apache migrated to mod-wsgi (python3), node source updated for Ubuntu
- **TELEVIR module** introduced — config-driven install, reference registration (`register_references_on_file`), EupathDB integration
- INSaFLU updated to v2.1–v2.1.1 (dsobral)

## Phase 2: SLURM Cluster Buildout (Jan–Apr 2025)

- Containerized full SLURM cluster on Ubuntu:
  - `slurmctld`, `slurmdbd`, compute nodes (`c1`, `c2`) as separate Docker services
  - Munge key management, shared `/run/munge`, user/group standardization
  - MySQL/MariaDB for accounting, SlurmDBD configuration
  - Node separation from management plane
- Software distribution to compute nodes: IRMA, FLUmut, BLAST+, ABRICATE, samtools, HMMER, Infernal, Prokka
- Dynamic node scaling support (dsobral)

## Phase 3: Stabilization & Refinement (May–Sep 2025)

- Entrypoint restructuring — `load_defaults` script, `system_paths.sh`, env file linking
- Python2 compat for Snippy, tbl2asn fixes, Apache/SLURM group integration
- Repository migrated to official `INSaFLU` GitHub org
- Media/static shared volumes, permission hardening

## Phase 4: Dynamic Scaling & Accounting (Oct 2025–May 2026)

- Docker Compose overhaul — global compose, node templates, `extend` pattern
- C1 node addition, SlurmDBD MySQL-backed accounting finalized
- TELEVIR reference registration automated, `generate_default_trees` moved to bash
- Medaka 2+ dependencies (abpoa), NCBI_EMAIL config, dotenv integration
- Slurm storage/accounting fully operational — storage user, slurmdbd→mysql pipeline
