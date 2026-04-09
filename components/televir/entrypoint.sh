#!/bin/bash

if [ "$1" = "move" ]; then
    echo "---> Create televir dbs in /opt/televir/ ..."
    
    if [ ! -d "/opt/televir" ]; then
        mkdir -p /opt/televir
    fi
    
    cd insaflu_web/TELEVIR
    cp install_scripts/config.py /opt/televir/config.py
    
    /opt/venv/bin/python main.py --docker --envs --setup_conda --seqdl --soft --partial
    
    chmod -R 0777 /opt/televir
    
    echo "---> Finshed creating televir dbs in /opt/televir/ ... done"
fi
