#!/bin/bash
set -e



move_slurm_key() {
    
    MUNGE_KEY_SRC=/run/secrets/munge.key
    MUNGE_KEY_DST=/etc/munge/munge.key
    
    if [ ! -s "$MUNGE_KEY_SRC" ]; then
        echo "FATAL: munge.key missing"
        exit 1
    fi
    
    # Ensure directory exists
    mkdir -p /etc/munge

    cp -f "$MUNGE_KEY_SRC" "$MUNGE_KEY_DST"
    chown munge:munge "$MUNGE_KEY_DST"
    chmod 400 "$MUNGE_KEY_DST"
}

copy_slurm_config() {
    if [ -d /run/secrets/slurm ]; then
        echo "---> Initializing Slurm config from secrets"
        cp -a /run/secrets/slurm/* /etc/slurm/
        
        chown -R slurm:slurm /etc/slurm
        
        # Strict permissions required by Slurm
        # (slurmdbd.conf is intentionally not mounted here - only the
        # slurmdbd container gets it, see components/slurm_master/entrypoint.sh)
        chmod 640 /etc/slurm/slurm.conf || true
        chmod 640 /etc/slurm/cgroup.conf || true
    fi
}

# build DBs and launch frontend
if [ "$1" = "init_all" ]; then
    echo "---> Starting the MUNGE Authentication service (munged) ..."
    move_slurm_key
    copy_slurm_config
    
    gosu munge munged --pid-file=/var/run/munge/munged.pid
    
    echo "---> Wait 45 seconds for all pgsql services  ..."
    sleep 45	## wait for postgis extension
    
    ### need to link after the mount, otherwise all the data in "/insaflu_web/INSaFLU/env" is going to be masked (hided)
    if [ -f "/insaflu_web/INSaFLU/env/insaflu.env" ]; then
        echo "---> Linking insaflu.env to .env ..."
        if [ -e "/insaflu_web/INSaFLU/.env" ]; then
            echo "---> Removing existing .env file ..."
            rm -f /insaflu_web/INSaFLU/.env
        fi
        cp /insaflu_web/INSaFLU/env/insaflu.env /insaflu_web/INSaFLU/.env
    fi
    
    ### set all default insaflu data
    echo "---> Collect static data  ..."
    cd /insaflu_web/INSaFLU; /usr/bin/python3 manage.py collectstatic --noinput;
    
    echo "---> Create/Update database if necessary  ..."
    cd /insaflu_web/INSaFLU; /usr/bin/python3 manage.py makemigrations; /usr/bin/python3 manage.py migrate;
    
    ### set owners
    echo "---> Set owners APP_USER ..."
    chown -R APP_USER:slurm /insaflu_web/INSaFLU/media
    chown -R APP_USER:slurm /var/log/insaFlu
    ### This s for televir
    chown -R APP_USER:slurm /insaflu_web/INSaFLU/static_all
    
    ### some files/paths are made by "root" account and need to be accessed by "flu_user"
    ### It's done by tmpfiles.d
    rm -rf /tmp/insaFlu/*
    if [ -d "/tmp/insaFlu" ]; then
        chmod -R 0777 /tmp/insaFlu
    fi
    
    chmod -R 0777 /insaflu_web/INSaFLU/media
    chmod -R 0777 /insaflu_web/INSaFLU/static_all
    chmod -R 0777 /var/log/insaFlu
    
    ### set default files and settings, deploy using slurm
    echo "---> Set default files and settings  ..."
    echo APP_USER
    mkdir -p /data/tmp && cd /data/tmp/;  chown -R APP_USER:slurm /data/;
    cp /insaflu_web/commands/load_defaults.sh .
    sbatch load_defaults.sh
    cd /insaflu_web/INSaFLU;
    
    ## for televir
    echo "--->  Set up TELEVIR software  ..."
    if [ -e /opt/televir/utility_docker.db ]; then
        #/usr/bin/python3 manage.py register_references_on_file -o /tmp/insaFlu/register
        cd /data/tmp/ && cp /insaflu_web/commands/register_televir_refs.sh . && gosu flu_user sbatch register_televir_refs.sh
        cd /insaflu_web/INSaFLU;
    fi
    
    echo "---> Start apache server  ..."
    service apache2 start
    echo "---> apache running  ..."

    tail -f /dev/null
fi


