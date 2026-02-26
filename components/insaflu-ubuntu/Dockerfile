
FROM slurm-runtime:slurm-25.05
USER root


# version
ADD VERSION .
ARG DEBIAN_FRONTEND=noninteractive
ARG RUNLEVEL=1
ARG GOSU_VERSION=1.17
ARG SLURM_TAG
ARG APP_USER
ARG SHARED_USER_NAME=user
ARG SHARED_USER_UID=1000
ARG SHARED_GROUP_NAME=user
ARG SHARED_GROUP_GID=1000

LABEL vendor=INSA\
      pt.insa.insaflu.is-production="" \
      pt.insa.insaflu.version="1.7.0-beta" \
      pt.insa.insaflu.release-date="2023-06-13"


RUN mkdir -p /tmp_install
RUN mkdir -p /software
RUN mkdir -p /tmp/insaFlu

ADD configs/ /tmp_install/configs/
ADD commands/ /tmp_install/commands/
ADD software/ /tmp_install/software/
ADD install_scripts/*.sh /tmp_install/

############# APP AND REQUIRED SOFTWARE
RUN sh /tmp_install/install_system_pkgs.sh
RUN sh /tmp_install/install_apache.sh
#RUN sh /tmp_install/install_slurm.sh

USER root

RUN sh /tmp_install/install_miniconda.sh
RUN sh /tmp_install/install_software.sh


RUN sh /tmp_install/install_website_dependencies.sh
RUN sh /tmp_install/install_website.sh


RUN apt-get update \
      && apt-get install -y sudo

# Slurm client binaries
ADD entrypoint.sh /tmp_install/
RUN sh /tmp_install/install_finish.sh

RUN apt-get update && apt-get install -y bash-completion wget
RUN echo 'PATH="/opt/sge/bin:/opt/sge/bin/lx-amd64:/insaflu_web/commands/:/software/kallisto_linux-v0.43.1/:/software/blast+/2.16.0/ncbi-blast-2.16.0+-src/c++/ReleaseMT/bin:${PATH}"' >> /home/${APP_USER}/.bashrc
RUN echo 'PATH="/opt/sge/bin:/opt/sge/bin/lx-amd64:/insaflu_web/commands/:/software/kallisto_linux-v0.43.1/:/software/blast+/2.16.0/ncbi-blast-2.16.0+-src/c++/ReleaseMT/bin:${PATH}"' >> /root/.bashrc
RUN echo 'export PATH="/opt/sge/bin:/opt/sge/bin/lx-amd64:/insaflu_web/commands/:/software/kallisto_linux-v0.43.1/:/software/blast+/2.16.0/ncbi-blast-2.16.0+-src/c++/ReleaseMT/bin:${PATH}"' >> /etc/apache2/envvars
RUN echo 'export USER=${APP_USER}' >> /etc/apache2/envvars
RUN echo 'export HOME=/home/${APP_USER}' >> /etc/apache2/envvars

#USER ${APP_USER}

ENTRYPOINT ["/entrypoint.sh"]
