#!/bin/bash
set -e

cd /software
pip3 install virtualenv
virtualenv medaka --python=python3 --prompt "(medaka 2.2.0) "
. medaka/bin/activate
pip3 install --upgrade setuptools==80.9.0
pip3 install --no-cache-dir medaka==2.2.0
pip3 install --no-cache-dir numpy==1.26.4
pip3 install --no-cache-dir pyabpoa==1.5.5

cd medaka

#Install minimap
# cd
mkdir -p extra_software
cd extra_software
git clone https://github.com/lh3/minimap2.git
cd minimap2/
make

## install abpoa
cd ..
wget https://github.com/yangao07/abPOA/releases/download/v1.5.5/abPOA-v1.5.5.tar.gz
tar -zxvf abPOA-v1.5.5.tar.gz && rm abPOA-v1.5.5.tar.gz && cd abPOA-v1.5.5 && make

#Install HTSLIB
cd ..
apt-get install libcurl4-openssl-dev -y
wget https://github.com/samtools/htslib/releases/download/1.11/htslib-1.11.tar.bz2
tar -vxjf htslib-1.11.tar.bz2
cd htslib-1.11
make
cd ..
rm htslib-1.11.tar.bz2

#Install SAMTOOLS
wget https://github.com/samtools/samtools/releases/download/1.11/samtools-1.11.tar.bz2
tar -vxjf samtools-1.11.tar.bz2
cd samtools-1.11
make
cd ..
rm samtools-1.11.tar.bz2

#Install BCFTools
wget https://github.com/samtools/bcftools/releases/download/1.11/bcftools-1.11.tar.bz2
tar -vxjf bcftools-1.11.tar.bz2
cd bcftools-1.11
make
cd ..
rm bcftools-1.11.tar.bz2

### links
cd ../bin
ln -s ../extra_software/minimap2/minimap2 .
ln -s ../extra_software/htslib-1.11/bgzip .
ln -s ../extra_software/htslib-1.11/tabix .
ln -s ../extra_software/samtools-1.11/samtools .
ln -s ../extra_software/bcftools-1.11/bcftools .
ln -s ../extra_software/abPOA-v1.5.5/abpoa .

