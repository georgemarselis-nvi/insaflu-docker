#!/bin/bash
set -e

move_munge_key() {

    MUNGE_KEY_SRC=/run/secrets/munge.key
    MUNGE_KEY_DST=/etc/munge/munge.key

    if [ ! -s "$MUNGE_KEY_SRC" ]; then
        echo "FATAL: munge.key missing"
        exit 1
    fi

    # Ensure directory exists
    mkdir -p /etc/munge

    # Copy only if needed
    echo "Moving MUNGE key to $MUNGE_KEY_DST"
    cp -f "$MUNGE_KEY_SRC" "$MUNGE_KEY_DST"
    chown munge:munge "$MUNGE_KEY_DST"
    chmod 400 "$MUNGE_KEY_DST"
    echo "MUNGE key moved and permissions set."
    echo "MUNGE key is located at $MUNGE_KEY_DST"


}


copy_slurm_config() {
  if [ -d /run/secrets/slurm ]; then
    echo "---> Initializing Slurm config from secrets"
    cp -a /run/secrets/slurm/* /etc/slurm/

    chown -R slurm:slurm /etc/slurm
    echo `cat /etc/slurm/slurm.conf`
    echo `cat /etc/slurm/cgroup.conf`
    # Strict permissions required by Slurm
    # (slurmdbd.conf is intentionally not mounted here - only the
    # slurmdbd container gets it, see components/slurm_master/entrypoint.sh)
    chmod 640 /etc/slurm/slurm.conf || true
    chmod 640 /etc/slurm/cgroup.conf || true
  fi

    ## ensure var run slurm
    mkdir -p /var/run/slurm
    chown slurm:slurm /var/run/slurm

}


if [ "$1" = "slurmd" ]
then

    chown -R flu_user:slurm /software
    echo "---> Starting the MUNGE Authentication service (munged) ..."
    move_munge_key
    copy_slurm_config
    #service munge start
    gosu munge munged --pid-file=/var/run/munge/munged.pid
    echo "---> Waiting for slurmctld to become active before starting slurmd..."
    
    until 2>/dev/null >/dev/tcp/slurmctld/6817
    do
        echo "-- slurmctld is not available.  Sleeping ..."
        sleep 2
    done
    echo "-- slurmctld is now active ..."

    ### need to link after the mount, otherwise all the data in "/insaflu_web/INSaFLU/env" is going to be masked (hided)
    if [ -f "/insaflu_web/INSaFLU/env/insaflu.env" ]; then
        echo "---> Linking insaflu.env to .env ..."
        if [ -e "/insaflu_web/INSaFLU/.env" ]; then
            echo "---> Removing existing .env file ..."
            rm -f /insaflu_web/INSaFLU/.env
        fi
        cp /insaflu_web/INSaFLU/env/insaflu.env /insaflu_web/INSaFLU/.env
    fi
    
    echo "---> Starting the Slurm Node Daemon (slurmd) ..."
    exec /usr/sbin/slurmd -Dvvv

fi

exec "$@"
