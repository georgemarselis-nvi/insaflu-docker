#!/bin/bash
# Pull the latest INSaFLU application code inside the running containers.
#
# insaflu-ubuntu, c1, and c2 each have their own independent clone of
# /insaflu_web/INSaFLU baked in from their own image build (it's not a
# shared volume between them), so all three need pulling to stay in sync.
set -e

for c in insaflu-ubuntu c1 c2; do
    echo "=== $c ==="
    docker exec "$c" git -C /insaflu_web/INSaFLU pull
    echo
done
