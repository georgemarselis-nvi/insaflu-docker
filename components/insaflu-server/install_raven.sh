#!/bin/bash
# components/insaflu-server/install_raven.sh
# Creates the raven environment with pixi and installs the wrapper script.

set -e

export PIXI_HOME=/software/pixi

echo "Install raven"
pixi global install --environment raven --channel conda-forge --channel bioconda raven-assembler=1.8.1
ln -s /software/pixi/envs/raven /software/miniconda2/envs/raven
mv /tmp_install/software/raven/ /software/
chmod a+x /software/raven/raven.sh
