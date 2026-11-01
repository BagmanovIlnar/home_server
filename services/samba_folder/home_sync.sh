#!/usr/bin/env bash
# Автосинк домашних каталогов с пользователями AD (запускается фоном из run.sh)
#  - пользователь появился в AD  -> создаётся /var/home-service/users/<user> (владелец — доменный юзер, 0700)
#  - пользователь удалён из AD   -> каталог переносится в .deleted/<user>_<дата> (НЕ rm — защита данных
#    от ложного срабатывания; окончательное удаление — bash/del_user.sh)
# Гард: если DC недоступен (wbinfo -P) — цикл пропускается, ничего не архивируется.

BASE=/var/home-service/users
DELETED=$BASE/.deleted
INTERVAL=${SYNC_INTERVAL:-60}
SKIP_USERS="Administrator krbtgt Guest"

while :; do
    sleep "$INTERVAL"

    # DC доступен и winbind жив? Иначе пропускаем цикл
    wbinfo -P >/dev/null 2>&1 || continue
    wbinfo -u >/dev/null 2>&1 || continue

    # 1) создать отсутствующие домашние каталоги
    while IFS= read -r u; do
        [ -z "$u" ] && continue
        case " $SKIP_USERS " in *" $u "*) continue ;; esac
        case "$u" in *'$'*) continue ;; esac          # машинные учётки (NAS$, DC1$)
        home="$BASE/$u"
        if [ ! -d "$home" ]; then
            if mkdir -p "$home" && chown "$u:domain users" "$home" && chmod 700 "$home"; then
                echo "[home_sync] created home for $u"
            fi
        fi
    done < <(wbinfo -u)

    # 2) каталоги без пользователя в AD -> архивировать в .deleted
    for d in "$BASE"/*/; do
        [ -d "$d" ] || continue
        u=$(basename "$d")
        if ! wbinfo -n "$u" >/dev/null 2>&1; then
            mkdir -p "$DELETED"
            ts=$(date +%Y%m%d_%H%M%S)
            if mv "$d" "$DELETED/${u}_$ts"; then
                echo "[home_sync] archived $u -> .deleted/${u}_$ts (user not in AD)"
            fi
        fi
    done
done
