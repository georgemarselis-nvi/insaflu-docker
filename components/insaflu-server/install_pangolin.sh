#!/bin/bash
# components/insaflu-server/install_pangolin.sh
# Creates the pangolin environment with pixi and installs the wrapper scripts.

set -e

export PIXI_HOME=/software/pixi

echo "Install Pangolin"
mv /tmp_install/software/update_pangolin.sh /software
chmod a+x /software/update_pangolin.sh
mv /tmp_install/software/pangolin /software/
pixi global install --environment pangolin --channel conda-forge --channel bioconda python=3.8 pangolin=4.2
ln -s /software/pixi/envs/pangolin /software/miniconda2/envs/pangolin
chmod u+x /software/pangolin/pangolin.sh
