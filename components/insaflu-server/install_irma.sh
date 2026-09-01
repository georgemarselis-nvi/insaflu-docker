#!/bin/bash
# components/insaflu-server/install_irma.sh
# Creates the irma environment with pixi.

set -e

export PIXI_HOME=/software/pixi

echo "Install IRMA"
pixi global install --environment irma --channel conda-forge --channel bioconda irma=1.2.0
ln -s /software/pixi/envs/irma /software/miniconda2/envs/irma
