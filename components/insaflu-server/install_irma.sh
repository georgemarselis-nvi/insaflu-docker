#!/bin/bash
# components/insaflu-server/install_irma.sh
# Creates the irma environment with pixi.

set -e

echo "Install IRMA"
mkdir -p /software/pixi/irma
cd /software/pixi/irma
pixi init --channel conda-forge --channel bioconda
pixi workspace platform add linux-64 --glibc 2.17
pixi add irma=1.2.0
ln -s /software/pixi/irma/.pixi/envs/default /software/miniconda2/envs/irma
