#!/bin/sh
# Ace Stream Engine — движок с HTTP API на 6878
set -e
# фон: вычистка скачанных кешей (свежие файлы активных трансляций не трогаем)
/clean.sh &
exec /opt/acestream/start-engine \
  --client-console \
  --bind-all \
  --log-stdout --log-stdout-level info \
  "$@"
