ARG SLURM_TAG=25.05.3
FROM slurm-runtime:${SLURM_TAG}
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


### Locale - needed by Perl-based tools (Prokka, Snippy). Set as real ENV, not just a
### shell-profile export, so it applies to every process (root, flu_user, sbatch jobs,
### Apache/mod_wsgi subprocesses) rather than only flu_user's own interactive shells.
RUN apt-get update && apt-get install -y locales \
    && echo "en_US.UTF-8 UTF-8" > /etc/locale.gen \
    && locale-gen en_US.UTF-8 \
    && update-locale LANG=en_US.UTF-8
ENV LANG=en_US.UTF-8
ENV LANGUAGE=en_US:en
ENV LC_ALL=en_US.UTF-8

RUN mkdir -p /tmp_install
RUN mkdir -p /software

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
