ARG SLURM_TAG=25.05.3
FROM slurm-runtime:${SLURM_TAG}
USER root

LABEL org.opencontainers.image.source="https://github.com/giovtorres/slurm-docker-cluster" \
    org.opencontainers.image.title="slurm-docker-cluster" \
    org.opencontainers.image.description="Slurm Docker cluster on Ubuntu 20.04" \
    org.label-schema.docker.cmd="docker-compose up -d" \
    maintainer="Giovanni Torres"


ARG DEBIAN_FRONTEND=noninteractive
ARG GOSU_VERSION=1.17
ARG SLURM_TAG
ARG SHARED_USER_NAME=user
ARG SHARED_USER_UID=1000
ARG SHARED_GROUP_NAME=user
ARG SHARED_GROUP_GID=1000


RUN mkdir -p /tmp_install

ADD configs /tmp_install/configs
ADD software /tmp_install/software

###### 
ADD install_scripts/*.sh /tmp_install/

RUN sh /tmp_install/install_system_pkgs.sh
RUN sh /tmp_install/install_software.sh
RUN sh /tmp_install/install_website_and_dependencies.sh

######

COPY entrypoint.sh /usr/local/bin/entrypoint.sh
RUN chmod +x /usr/local/bin/entrypoint.sh
RUN chown slurm:slurm /usr/local/bin/entrypoint.sh

RUN apt-get update \
    && apt-get install -y sudo netcat-openbsd


RUN apt-get update && apt-get install -y bash-completion wget
RUN apt-get update \
    && apt-get install -y locales

### Set as real ENV, not just a shell-profile export, so it applies to every process
### (root, flu_user, slurmd job steps) rather than only flu_user's own interactive shells.
RUN echo "en_US.UTF-8 UTF-8" > /etc/locale.gen \
    && locale-gen en_US.UTF-8 \
    && update-locale LANG=en_US.UTF-8
ENV LANG=en_US.UTF-8
ENV LANGUAGE=en_US:en
ENV LC_ALL=en_US.UTF-8

RUN cat /tmp_install/configs/system_paths.sh >> /home/${APP_USER}/.bashrc
RUN cat /tmp_install/configs/system_paths.sh >> /root/.bashrc
RUN cat /tmp_install/configs/system_paths.sh >> /etc/apache2/envvars
RUN cp /tmp_install/configs/system_paths.sh /etc/profile.d/
#RUN echo 'PATH="/opt/sge/bin:/opt/sge/bin/lx-amd64:/insaflu_web/commands/:/software/kallisto_linux-v0.43.1/:/software/blast+/2.16.0/ncbi-blast-2.16.0+-src/c++/ReleaseMT/bin:${PATH}"' >> /home/${APP_USER}/.bashrc
#RUN echo 'PATH="/opt/sge/bin:/opt/sge/bin/lx-amd64:/insaflu_web/commands/:/software/kallisto_linux-v0.43.1/:/software/blast+/2.16.0/ncbi-blast-2.16.0+-src/c++/ReleaseMT/bin:${PATH}"' >> /root/.bashrc
#RUN echo 'export PATH="/opt/sge/bin:/opt/sge/bin/lx-amd64:/insaflu_web/commands/:/software/kallisto_linux-v0.43.1/:/software/blast+/2.16.0/ncbi-blast-2.16.0+-src/c++/ReleaseMT/bin:${PATH}"' >> /etc/apache2/envvars



ENTRYPOINT ["/usr/local/bin/entrypoint.sh"]

CMD ["slurmdbd"]