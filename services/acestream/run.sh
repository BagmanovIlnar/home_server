#!/bin/sh
# Ace Stream Engine — движок с HTTP API на 6878
set -e
exec /opt/acestream/start-engine \
  --client-console \
  --bind-all \
  --log-stdout --log-stdout-level info \
  "$@"
