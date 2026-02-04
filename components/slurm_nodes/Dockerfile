
FROM slurm-runtime:slurm-25.05
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

# Copy node management scripts
COPY scripts /scripts
RUN chmod +x /scripts/*.sh
RUN chown -R slurm:slurm /scripts

RUN mkdir -p /tmp/insaFlu && chown ${APP_USER}:slurm /tmp/insaFlu

RUN apt-get update \
    && apt-get install -y sudo netcat-openbsd

#RUN sacctmgr create account -i $APP_USER
#RUN sacctmgr create user -i $APP_USER
#RUN sacctmgr modify user $APP_USER set adminlevel=ALL

#RUN software/make_links.sh
RUN apt-get update && apt-get install -y bash-completion wget

RUN echo 'PATH="/opt/sge/bin:/opt/sge/bin/lx-amd64:/insaflu_web/commands/:/software/kallisto_linux-v0.43.1/:/software/blast+/2.16.0/ncbi-blast-2.16.0+-src/c++/ReleaseMT/bin:${PATH}"' >> /home/${APP_USER}/.bashrc
RUN echo 'PATH="/opt/sge/bin:/opt/sge/bin/lx-amd64:/insaflu_web/commands/:/software/kallisto_linux-v0.43.1/:/software/blast+/2.16.0/ncbi-blast-2.16.0+-src/c++/ReleaseMT/bin:${PATH}"' >> /root/.bashrc

RUN apt-get update \
    && apt-get install -y locales \
    && locale-gen en_US.UTF-8

RUN echo "export LC_CTYPE=en_US.UTF-8" >> /home/${APP_USER}/.bashrc
RUN echo "export LC_ALL=en_US.UTF-8" >> /home/${APP_USER}/.bashrc

ENTRYPOINT ["/usr/local/bin/entrypoint.sh"]

CMD ["slurmdbd"]