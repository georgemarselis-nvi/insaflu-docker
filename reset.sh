#!/bin/bash
set -e

source .env

echo "This will PERMANENTLY DELETE:"
echo "  - All containers/networks for this project (docker compose down -v)"
echo "  - Every volume this project owns (Postgres DB, Slurm accounting DB, software cache, etc.)"
echo "  - All files under BASE_PATH_DATA (${BASE_PATH_DATA})"
echo ""
read -p "Type 'yes' to continue: " confirm
if [ "$confirm" != "yes" ]; then
    echo "Aborted."
    exit 1
fi

docker compose down -v
rm -rf "${BASE_PATH_DATA}"

echo "Done. Run ./up.sh for a completely fresh deployment."
