#!/bin/bash
# components/insaflu-server/install_ivar.sh
# Creates the ivar environment with pixi and symlinks it into the conda envs
# directory, so "conda activate ivar" keeps working.
# PIXI_HOME must not be /software/miniconda2: pixi owns $PIXI_HOME/bin and
# would replace conda's python symlink.

set -e

export PIXI_HOME=/software/pixi

echo "Install iVar"
pixi global install --environment ivar --channel conda-forge --channel bioconda ivar=1.4.2 bedtools=2.31.0 bwa=0.7.17
ln -s /software/pixi/envs/ivar /software/miniconda2/envs/ivar
