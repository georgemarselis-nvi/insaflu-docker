FROM centos:7
LABEL authors="monsantopinheiro@gmail.com,daniel.sobral@insa.min-saude.pt"

# version
ADD VERSION .

LABEL vendor=INSA\
      pt.insa.insaflu.is-production="" \
      pt.insa.insaflu.version="1.7.0-beta" \
      pt.insa.insaflu.release-date="2023-06-13"

RUN mkdir -p /tmp_install

COPY . /tmp_install/

ENV APP_USER=flu_user

RUN sh /tmp_install/install_website.sh

# install_miniconda.sh used to install every conda environment and every
# Nextstrain tool in a single layer, so any failure late in the script rebuilt
# the whole thing. It now installs only the Miniconda2 bootstrap, and each
# environment or tool is a separate script and a separate layer below.
RUN sh /tmp_install/install_miniconda.sh
RUN sh /tmp_install/install_ivar.sh
RUN sh /tmp_install/install_aln2pheno.sh
RUN sh /tmp_install/install_flumut.sh
RUN sh /tmp_install/install_irma.sh
RUN sh /tmp_install/install_nextstrain.sh
RUN sh /tmp_install/install_label.sh
RUN sh /tmp_install/install_nextstrain_rsv.sh
RUN sh /tmp_install/install_nextstrain_mpx.sh
RUN sh /tmp_install/install_tsv_utils.sh
RUN sh /tmp_install/install_nextstrain_dengue.sh
RUN sh /tmp_install/install_nextstrain_builds.sh
RUN sh /tmp_install/install_pangolin.sh
RUN sh /tmp_install/install_raven.sh

RUN sh /tmp_install/install_software.sh

RUN sh /tmp_install/install_finish.sh

ENV PATH="/opt/sge/bin:/opt/sge/bin/lx-amd64:/insaflu_web/commands/:/software/kallisto_linux-v0.43.1/:${PATH}" 

ENTRYPOINT ["/entrypoint.sh"]
