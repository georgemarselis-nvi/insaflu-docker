# =========================
# Stage 1 — build Slurm
# =========================
FROM ubuntu:22.04 AS slurm-build
ARG SLURM_TAG

RUN apt-get update && apt-get install -y \
    build-essential \
    git \
    munge \
    libmunge-dev \
    mariadb-server \
    libmariadb-dev \
    libhttp-parser-dev \
    libjson-c-dev \
    python3-dev \
    libcap-dev \
    libdbus-1-dev \
    libpam0g-dev \
    python3 \
    wget \
    ca-certificates \
    && rm -rf /var/lib/apt/lists/*

WORKDIR /build

RUN set -x \
    && git clone -b ${SLURM_TAG} --single-branch --depth=1 https://github.com/SchedMD/slurm.git \
    && cd slurm \
    && ./configure --enable-debug --prefix=/usr --sysconfdir=/etc/slurm \
    --with-mysql_config=/usr/bin  --libdir=/usr/lib/x86_64-linux-gnu \
    --enable-pam --enable-cgroup --disable-systemd \
    && make install \
    && install -D -m644 etc/cgroup.conf.example /etc/slurm/cgroup.conf.example \
    && install -D -m644 etc/slurm.conf.example /etc/slurm/slurm.conf.example \
    && install -D -m644 etc/slurmdbd.conf.example /etc/slurm/slurmdbd.conf.example \
    && install -D -m644 contribs/slurm_completion_help/slurm_completion.sh /etc/profile.d/slurm_completion.sh \
    && cd .. \
    && rm -rf slurm \
    && mkdir -p /etc/sysconfig/slurm \
    /var/spool/slurmd \
    /var/run/slurmd \
    /var/run/slurmdbd \
    /var/lib/slurmd \
    /var/log/slurm \
    /data 

# =========================
# Stage 2 — runtime
# =========================

FROM ubuntu:22.04 AS slurm-runtime

ARG DEBIAN_FRONTEND=noninteractive
ARG GOSU_VERSION=1.17
ARG SHARED_USER_UID=1000

# Users/groups MUST match across all containers
RUN set -x \
    && groupadd -r --gid=990 slurm \
    && useradd -r -g slurm --uid=990 slurm

RUN set -x \
    && groupadd -r --gid=102 munge \
    && useradd -r -g munge --uid=102 -d /var/lib/munge -s /sbin/nologin munge


ENV APP_USER=flu_user
RUN useradd -ms /bin/bash ${APP_USER} -r -g slurm --uid=${SHARED_USER_UID} 

RUN apt-get update && apt-get install -y \
    munge mariadb-client psmisc bash-completion \
    ca-certificates wget gnupg \
    && rm -rf /var/lib/apt/lists/*

# gosu
RUN wget -O /usr/local/bin/gosu https://github.com/tianon/gosu/releases/download/${GOSU_VERSION}/gosu-amd64 \
    && chmod +x /usr/local/bin/gosu

# Slurm binaries
COPY --from=slurm-build /usr /usr
COPY --from=slurm-build /etc/slurm /etc/slurm
COPY --from=slurm-build /etc/profile.d/slurm_completion.sh /etc/profile.d/

RUN mkdir -p \
    /var/log/slurm \
    /var/run/slurmd \
    /var/run/slurmdbd \
    /var/lib/slurmd \
    /var/lib/slurmctld \
    /var/run/munge \
    /var/spool/slurm \
    /var/spool/slurmd \
    /data \
    && chown -R slurm:slurm /var/*/slurm* \
    && /sbin/mungekey -cf \
    && chown -R munge:munge /etc/munge \
    && chmod 600 /etc/munge/munge.key \
    && chmod 755 /etc/munge \
    && mkdir -p /run/munge \
    && chown -R munge:munge /run/munge \
    && chmod 755 /run/munge

COPY configs/munge/munged.pid /var/run/munge/munged.pid
RUN chown munge:munge /var/run/munge/munged.pid

RUN mkdir -p /etc/slurm \
    && chown slurm:slurm /etc/slurm \
    && chmod 755 /etc/slurm

RUN mkdir -p /var/run/slurm \
    && chown -R slurm:slurm /var/run/slurm \
    && chmod 755 /var/run/slurm

COPY entrypoint.sh /usr/local/bin/entrypoint.sh
RUN chmod +x /usr/local/bin/entrypoint.sh

ENTRYPOINT ["/usr/local/bin/entrypoint.sh"]
CMD ["slurmdbd"]