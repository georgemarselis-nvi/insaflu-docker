#!/bin/bash
# components/insaflu-server/install_flumut.sh
# Creates the flumut environment with pixi.

set -e

export PIXI_HOME=/software/pixi

echo "Install FluMut"
pixi global install --environment flumut --channel conda-forge --channel bioconda flumut=0.6.3
ln -s /software/pixi/envs/flumut /software/miniconda2/envs/flumut
