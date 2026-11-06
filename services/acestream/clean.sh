#!/bin/sh
# Вычистка временных файлов, скачанных движком для трансляций/VOD
# (~/.AceStream/cache — куски торрентов, /tmp/.ACESTREAM* — буферы).
# Свежие файлы не трогаем: их может читать активная трансляция.
# env: ACE_CLEAN_INTERVAL (сек, 3600) — период; ACE_CLEAN_MIN_AGE (мин, 120) —
# что считать мусором; ACE_HOME (для тестов, /root/.AceStream).

ACE_HOME=${ACE_HOME:-/root/.AceStream}
INTERVAL=${ACE_CLEAN_INTERVAL:-3600}
MIN_AGE=${ACE_CLEAN_MIN_AGE:-120}

clean_once() {
  # куски торрентов/кеш трансляций + временные каталоги движка, старше MIN_AGE минут
  # (сам каталог не трогаем: его mtime свежий после любой записи)
  find "$ACE_HOME/cache" "$ACE_HOME/tmp" -depth -mindepth 1 -mmin +"$MIN_AGE" -delete 2>/dev/null
  for d in /tmp/.ACESTREAM*; do
    [ -d "$d" ] || continue
    find "$d" -depth -mindepth 1 -mmin +"$MIN_AGE" -delete 2>/dev/null
    rmdir "$d" 2>/dev/null
  done
  echo "acestream-cache: on disk $(du -sh "$ACE_HOME" 2>/dev/null | cut -f1)"
}

# разовый прогон для тестов: ACE_CLEAN_ONCE=1
if [ "$ACE_CLEAN_ONCE" = "1" ]; then
  clean_once
  exit 0
fi

while :; do
  sleep "$INTERVAL"
  clean_once
done
