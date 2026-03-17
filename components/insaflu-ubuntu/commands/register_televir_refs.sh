#!/bin/bash
#SBATCH --export=ALL
#SBATCH --job-name=register_references
#SBATCH --ntasks=1
#SBATCH --output=/data/tmp/%x_%j_register.out
#SBATCH --error=/data/tmp/register_televir_references_err.out


/usr/bin/python3 /insaflu_web/INSaFLU/manage.py generate_default_trees
/usr/bin/python3 /insaflu_web/INSaFLU/manage.py register_references_on_file --user_id 1 -o /tmp/insaFlu/register_references