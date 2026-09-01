#!/bin/bash
# components/insaflu-server/install_nextstrain_mpx.sh
# Creates the nextstrain_mpx environment with pixi.

set -e

export PIXI_HOME=/software/pixi

echo "Install Nextstrain MPX"
pixi global install --environment nextstrain_mpx --channel conda-forge --channel bioconda python=3.8 biopython=1.74 nextstrain-cli=4.2.0 augur=17.1.0 auspice=2.38.0 nextalign=2.5.0 nextclade=2.5.0 snakemake git epiweeks=2.1.4 pangolin=2.4.2 pangolearn=2021.05.27 seqkit=2.3.0
ln -s /software/pixi/envs/nextstrain_mpx /software/miniconda2/envs/nextstrain_mpx
