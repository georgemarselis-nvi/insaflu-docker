#!/bin/bash
# components/insaflu-server/install_nextstrain_rsv.sh
# Creates the nextstrain_rsv environment with pixi.

set -e

export PIXI_HOME=/software/pixi

echo "Install Nextstrain RSV"
pixi global install --environment nextstrain_rsv --channel conda-forge --channel bioconda python=3.10 augur=20.0 auspice=2.42 nextalign=2.9.1 nextclade=2.9.1 snakemake git epiweeks=2.1.4
ln -s /software/pixi/envs/nextstrain_rsv /software/miniconda2/envs/nextstrain_rsv
