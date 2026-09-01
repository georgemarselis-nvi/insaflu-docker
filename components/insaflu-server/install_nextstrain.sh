#!/bin/bash
# components/insaflu-server/install_nextstrain.sh
# Creates the nextstrain environment with pixi and installs the wrapper scripts.

set -e

export PIXI_HOME=/software/pixi

echo "Install Nextstrain"
pixi global install --environment nextstrain --channel conda-forge --channel bioconda python=3.9 nextstrain-cli=3.2.4 augur=15.0.2 auspice nextalign=1.11.0 nextclade=1.11.0 snakemake git epiweeks pangolin pangolearn
ln -s /software/pixi/envs/nextstrain /software/miniconda2/envs/nextstrain
mv /tmp_install/software/nextstrain/ /software/
chmod u+x /software/nextstrain/nextstrain.sh
chmod u+x /software/nextstrain/nextstrain_mpx.sh
chmod u+x /software/nextstrain/auspice_tree_to_table.sh
chmod u+x /software/nextstrain/nextstrain_snake.sh
chmod u+x /software/nextstrain/nextstrain_rsv.sh
chmod u+x /software/nextstrain/scripts/auspice_tree_to_table.py
