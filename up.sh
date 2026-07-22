#!/bin/bash
set -ex

source .env

if [ ! -d "${BASE_PATH_DATA}/postgres/postgres_data" ]; then 
	mkdir -p ${BASE_PATH_DATA}/postgres/postgres_data
fi
if [ ! -d "${BASE_PATH_DATA}/postgres/backups" ]; then 
	mkdir -p ${BASE_PATH_DATA}/postgres/backups
fi
if [ ! -d "${BASE_PATH_DATA}/insaflu/data/all_data" ]; then 
	mkdir -p ${BASE_PATH_DATA}/insaflu/data/all_data
fi
if [ ! -d "${BASE_PATH_DATA}/insaflu/data/predefined_dbs" ]; then
	mkdir -p ${BASE_PATH_DATA}/insaflu/data/predefined_dbs
fi
if [ ! -d "${BASE_PATH_DATA}/insaflu/data/static" ]; then
	mkdir -p ${BASE_PATH_DATA}/insaflu/data/static
fi
if [ ! -d "${BASE_PATH_DATA}/insaflu/env" ]; then
	mkdir -p ${BASE_PATH_DATA}/insaflu/env
fi
if [ ! -d "${BASE_PATH_DATA}/insaflu/log/insaFlu" ]; then
	mkdir -p ${BASE_PATH_DATA}/insaflu/log/insaFlu
	chmod 777 ${BASE_PATH_DATA}/insaflu/log/insaFlu
fi
if [ ! -d "${BASE_PATH_DATA}/insaflu/log/httpd" ]; then
	mkdir -p ${BASE_PATH_DATA}/insaflu/log/httpd
fi
if [ ! -f "${BASE_PATH_DATA}/insaflu/env/insaflu.env" ]; then
	cp components/insaflu-ubuntu/configs/insaflu.env ${BASE_PATH_DATA}/insaflu/env/
fi
if [ ! -d "${BASE_PATH_DATA}/televir" ]; then
	mkdir -p ${BASE_PATH_DATA}/televir
fi
if [ ! -d "${BASE_PATH_DATA}/workdir" ]; then
	mkdir -p ${BASE_PATH_DATA}/workdir
fi

# image name
export IMAGE=insaflu-ubuntu

echo "Starting INSaFLU services ..."
docker compose up -d ${IMAGE}

echo ""
echo "==================================================================="
echo "INSaFLU is now running, along with its Slurm cluster (c1/c2 compute"
echo "nodes are started automatically as dependencies of ${IMAGE})."
echo ""
echo "To follow startup progress:"
echo "  docker logs -f insaflu-ubuntu"
echo ""
echo "To check cluster/container status:"
echo "  ./cluster-status.sh"
echo ""
echo "To stop everything:"
echo "  ./stop.sh"
echo "==================================================================="
