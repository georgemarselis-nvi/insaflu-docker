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
        
        # Strict permissions required by Slurm
        # (slurmdbd.conf is copied/chmod'd separately below, only for the
        # slurmdbd container - it's never present here at this point)
        chmod 600 /etc/slurm/slurm.conf || true
        chmod 600 /etc/slurm/cgroup.conf || true
    fi
}


if [ "$1" = "slurmdbd" ]
then
    
    move_munge_key
    echo `ls /run/secrets/slurm`
    copy_slurm_config

    if [ -f /run/secrets/slurmdbd.conf ]; then
        cp -f /run/secrets/slurmdbd.conf /etc/slurm/slurmdbd.conf
        chown slurm:slurm /etc/slurm/slurmdbd.conf
        chmod 600 /etc/slurm/slurmdbd.conf
    fi

    echo "---> Starting the MUNGE Authentication service (munged) ..."
    #service munge start
    gosu munge munged --pid-file=/var/run/munge/munged.pid
    echo "---> Starting the Slurm Database Daemon (slurmdbd) ..."
    echo `ls /etc/slurm`
    {
        . /etc/slurm/slurmdbd.conf
        until echo "SELECT 1" | mysql -h $StorageHost -u$StorageUser -p$StoragePass 2>&1 > /dev/null
        do
            echo "-- Waiting for database to become active ..."
            sleep 2
        done
    }
    echo "-- Database is now active ..."
    # print slurmdbd version
    echo "slurmdbd version:" $(/usr/sbin/slurmdbd -V)
    
    exec gosu slurm /usr/sbin/slurmdbd -Dvvv
fi

if [ "$1" = "slurmctld" ]
then
    
    move_munge_key
    copy_slurm_config
    
    echo "---> Starting the MUNGE Authentication service (munged) ..."
    #service munge start
    gosu munge munged --pid-file=/var/run/munge/munged.pid
    
    echo "---> Waiting for slurmdbd to become active before starting slurmctld ..."
    echo `cat /etc/slurm/slurm.conf`
    
    until 2>/dev/null >/dev/tcp/slurmdbd/6819
    do
        echo "-- slurmdbd is not available.  Sleeping ..."
        sleep 2
    done
    echo "-- slurmdbd is now active ..."
    
    echo "---> Starting the Slurm Controller Daemon (slurmctld) ..."
    if /usr/sbin/slurmctld -V | grep -q '21.08.06' ; then
        exec gosu slurm /usr/sbin/slurmctld -Dvvv
    else
        exec gosu slurm /usr/sbin/slurmctld -i -Dvvv
    fi
fi

if [ "$1" = "slurmd" ]
then
    
    move_munge_key
    copy_slurm_config
    
    echo "---> Starting the MUNGE Authentication service (munged) ..."
    #service munge start
    gosu munge munged --pid-file=/var/run/munge/munged.pid
    echo "---> Waiting for slurmctld to become active before starting slurmd..."
    
    until 2>/dev/null >/dev/tcp/slurmctld/6817
    do
        echo "-- slurmctld is not available.  Sleeping ..."
        sleep 2
    done
    echo "-- slurmctld is now active ..."
    
    echo "---> Starting the Slurm Node Daemon (slurmd) ..."
    exec /usr/sbin/slurmd -Dvvv
fi

exec "$@"
