#!/bin/sh

# =====================================================================
# update_hybrid6.sh
# =====================================================================
# Изменения относительно update_hybrid5.sh (кодовое имя v6):
#   1. Порт-пул финального сервиса сдвинут на +100 (20081-85 -> 20181-85),
#      имя итогового конфига и pid-файла изменены, чтобы НЕ конфликтовать
#      со старой (v5) версией, если она ещё где-то запущена.
#   2. Trap теперь вешается через EXIT (а не только INT/TERM) и содержит
#      защиту "restart-pending": если скрипт прервётся ровно между
#      stop_main и start_main в финальной сборке, trap гарантированно
#      поднимет main обратно, а не оставит роутер без прокси.
#   3. Перед финальным start_main добавлена валидация `sing-box check`
#      готового конфига (раньше проверялись только тестовые конфиги).
#   4. Фильтр ENCRYPTION_PRIORITY=2/3 исправлен: trojan без TLS больше не
#      проходит фильтр "как есть" (баг был в обеих ветках, не только в одной).
#   5. Кэш пулов ANCHOR/EXIT объединён в один общий кэш ПО ПРОТОКОЛУ
#      (а не по роли anchor/exit): нода тестируется на скорость только
#      один раз за прогон вне зависимости от того, сколько раз и в какой
#      роли этот протокол понадобится по ходу перебора CHAIN_TYPES.
#      Сканирование протокола продолжается с того места, где остановилось
#      в прошлый раз (не тестируем повторно уже отбракованные ноды).
#   6. all_nodes.json фильтруется по протоколу (ss/vless/trojan) один раз
#      за прогон, а не заново на каждой итерации CHAIN_TYPES.
#   7. Убран base64+eval блок, дублирующий уже установленные значения
#      (тот же паттерн, что и в update_tor3.sh) - заменён на обычный
#      `: ${VAR:=default}` без обфускации.
#   8. Дублирующаяся логика "запустить sing-box + дождаться Clash API"
#      вынесена в общую функцию start_tester() (таймауты каждого вызова
#      сохранены как в оригинале: Fast Check=15, gather_pool=20, chain=25).
#   9. kill_testers/stop_main проверяют реальный cmdline процесса через
#      /proc/$PID/cmdline вместо того, чтобы полагаться на вывод `ps`,
#      который на urezanном busybox часто не показывает полные аргументы.
#  10. start_main проверяет, что PID из pidfile - это действительно
#      живой sing-box, а не переиспользованный чужой PID.
#  11. Добавлена явная проверка наличия `lua`, `converter.lua` и свободного
#      места на диске до начала тяжёлой работы.
#  12. Добавлено логирование основного (боевого) процесса в файл вместо
#      /dev/null (тестовые процессы по-прежнему тихие, чтобы не плодить
#      мусор на flash - их таких запусков за один прогон могут быть сотни).
#  13. Тихая потеря нод при сбое base64-декодера подписки теперь видна:
#      если ни исходный, ни декодированный текст не похож на ss/vless/
#      trojan-ссылки, источник помечается предупреждением, а не молчанием.
#
# --- Правки по результатам первого реального запуска на роутере ---
#  14. Проверка lua была основана только на `command -v lua`, который на
#      этом роутере не находит интерпретатор, хотя тот реально работает
#      в интерактивном шелле (похоже на alias/функцию в .profile, которая
#      не наследуется скриптом). Теперь ищем явно по стандартным путям
#      Entware (/opt/bin/lua и т.п.), а найденный путь кладём в LUA_BIN
#      и используем его во всех вызовах вместо голого "lua".
#  15. Fast Check реально тестировал 100% существующих цепочек, а не
#      останавливался при достижении 70%-порога, хотя лог заявлял
#      "0% Load" - порог влиял только на решение "делать ли полный
#      ребилд", но не на сам цикл проверки. Добавлен break сразу по
#      достижении STABLE_THRESHOLD.
#
# ВСЕ таймауты, sleep, max-time, размеры батчей, квоты протоколов,
# пороги скорости и тестовый URL/размер файла ОСТАВЛЕНЫ БЕЗ ИЗМЕНЕНИЙ -
# менялась только логика, а не тюнинг производительности.
# =====================================================================

# === ЦВЕТА / COLORS ===
GREEN='\033[1;32m'
RED='\033[1;31m'
YELLOW='\033[1;33m'
BLUE='\033[1;34m'
CYAN='\033[1;36m'
PURPLE='\033[1;35m'
RESET='\033[0m'

echo -e "${CYAN}"
cat << 'EOF'
      /\_/\   [PROXY HYBRID MODULE v6]
     ( o.o )
      > ^ <   Cross-Protocol Breeder
           |\__/,|   (`\
         _.|o o  |_   ) )
        -(((---(((--------
EOF
echo -e "${RESET}"

# =====================================================================
# ПОЛЬЗОВАТЕЛЬСКИЕ НАСТРОЙКИ (МОЖНО РЕДАКТИРОВАТЬ)
# =====================================================================
CHAIN_TYPES="ss-ss ss-vless ss-trojan vless-ss trojan-ss"

ENCRYPTION_PRIORITY=1
ANCHOR_POOL_SIZE=5
EXIT_POOL_SIZE=10
WANTED_CHAINS=6
MIN_POOL_SPEED_KBPS=700
MIN_CHAIN_SPEED_KBPS=400

# =====================================================================
# ЗАЩИТНЫЙ БЛОК (ДЕФОЛТЫ) - без обфускации, просто fallback на случай,
# если один из пунктов выше был случайно закомментирован/удалён.
# =====================================================================
: ${CHAIN_TYPES:="ss-ss ss-vless ss-trojan vless-ss trojan-ss"}
: ${ANCHOR_POOL_SIZE:=5}
: ${EXIT_POOL_SIZE:=10}
: ${WANTED_CHAINS:=6}
: ${MIN_POOL_SPEED_KBPS:=700}
: ${MIN_CHAIN_SPEED_KBPS:=400}
: ${ENCRYPTION_PRIORITY:=1}

# =====================================================================
# ВАЛИДАЦИЯ ТИПОВ И РЕЖИМА ШИФРОВАНИЯ
# =====================================================================
echo -e "${CYAN}[HYBRID] Validating Configuration...${RESET}"

echo -e "  ${PURPLE}➔ Encryption Priority:${RESET}"
case "$ENCRYPTION_PRIORITY" in
    1) echo -e "    ${GREEN}[Mode 1] Mixed/Base: Secure and Naked nodes are processed together.${RESET}" ;;
    2) echo -e "    ${GREEN}[Mode 2] Strict: Naked nodes (no TLS / method:none) are explicitly dropped.${RESET}" ;;
    3) echo -e "    ${GREEN}[Mode 3] Fallback: Secure nodes are tested first, Naked nodes used as backup.${RESET}" ;;
    *) echo -e "    ${YELLOW}[WARN] Unknown Mode. Defaulting to Mode 1 (Mixed/Base).${RESET}"; ENCRYPTION_PRIORITY=1 ;;
esac

echo -e "  ${PURPLE}➔ Chain Sequences:${RESET}"
VALIDATED_CHAINS=""
for TYPE in $CHAIN_TYPES; do
    case "$TYPE" in
        ss-ss|ss-vless|ss-trojan|vless-ss|trojan-ss)
            VALIDATED_CHAINS="$VALIDATED_CHAINS $TYPE " ;;
        vless-vless|trojan-trojan|vless-trojan|trojan-vless)
            echo -e "    ${YELLOW}[SKIP] $TYPE : Эффект «Матрешки» (Nested TLS). Исключено.${RESET}" ;;
        *hy2*|*tuic*)
            echo -e "    ${YELLOW}[SKIP] $TYPE : Каскады UDP временно не поддерживаются.${RESET}" ;;
        *)
            echo -e "    ${RED}[SKIP] $TYPE : Синтаксическая ошибка.${RESET}" ;;
    esac
done

CHAIN_TYPES=$(echo "$VALIDATED_CHAINS" | sed -e 's/^[[:space:]]*//' -e 's/[[:space:]]*$//')
if [ -z "$CHAIN_TYPES" ]; then
    echo -e "${RED}[FATAL] No valid chain types provided! Exiting.${RESET}"
    exit 1
fi
echo -e "    ${GREEN}Approved sequence: [ $CHAIN_TYPES ]${RESET}"

# =====================================================================
# СЛУЖЕБНЫЕ НАСТРОЙКИ И ПУТИ
# =====================================================================
TEST_PORT=25556
TEST_API_PORT=9093

WORKDIR="/opt/tmp_sb_ext/sing-box-1.13.12-extended-2.4.1-linux-mipsle"
BIN="$WORKDIR/sing-box"
CONF_BASE="$WORKDIR/conf3_final.json"

# --- v6: новое имя итогового конфига/pid/лога, порт-пул сдвинут на +100 ---
CONF_TARGET="$WORKDIR/conf_chain6.json"
MAIN_PIDFILE="/var/run/sb_chain6_main.pid"
LOGFILE="$WORKDIR/sb_chain6.log"
PORT_SHIFT=100
# База conf3_final.json: 20081-20085 -> после сдвига: 20181-20185

# Лог main-процесса не ротируется автоматически ничем внешним - обрезаем
# сами, если он вырос больше ~1MB, чтобы не забивать flash за месяцы работы.
if [ -f "$LOGFILE" ]; then
    LOG_SIZE=$(wc -c < "$LOGFILE" 2>/dev/null); LOG_SIZE=${LOG_SIZE:-0}
    if [ "$LOG_SIZE" -gt 1048576 ] 2>/dev/null; then
        : > "$LOGFILE"
    fi
fi

ACTIVE_TEST_URL="https://speed.cloudflare.com/__down?bytes=15000000"
TEST_URLS="$ACTIVE_TEST_URL https://cachefly.cachefly.net/10mb.test"
MAX_ACCEPTABLE_PING=4000
TEST_PID=""

SUBS_LIST="
https://sub.whitedns.one/sub/base64.txt
https://raw.githubusercontent.com/sakha1370/OpenRay/refs/heads/main/output/all_valid_proxies.txt
https://raw.githubusercontent.com/SoliSpirit/v2ray-configs/refs/heads/main/Protocols/ss.txt
https://raw.githubusercontent.com/ebrasha/free-v2ray-public-list/refs/heads/main/all_extracted_configs.txt
"

FREE_RAM=$(awk '/MemFree/ {free=$2} /Buffers/ {buf=$2} /^Cached/ {cache=$2} END {print int((free+buf+cache)/1024)}' /proc/meminfo 2>/dev/null || echo 0)
if [ "$FREE_RAM" -gt 150 ]; then TEMP="/tmp/sb_chain6_tmp"; else TEMP="$WORKDIR/sb_chain6_tmp"; fi

# =====================================================================
# ПРЕДВАРИТЕЛЬНЫЕ ПРОВЕРКИ ОКРУЖЕНИЯ (v6)
# =====================================================================
check_disk_space() {
    local free_kb
    free_kb=$(df -k "$WORKDIR" 2>/dev/null | tail -1 | awk '{print $4}')
    if [ -n "$free_kb" ] && [ "$free_kb" -lt 10240 ] 2>/dev/null; then
        echo -e "${RED}[FATAL] Свободного места < 10MB в $WORKDIR. Останов.${RESET}"
        return 1
    fi
    return 0
}

LUA_BIN=""

# command -v lua может не найти интерпретатор, даже если в интерактивном
# шелле "lua" прекрасно запускается - на некоторых Entware-сборках это
# alias/функция из .profile, которая не наследуется скриптом, а не
# реальный файл в PATH. Поэтому ищем явно по стандартным путям Entware,
# и только в самом конце пробуем голый вызов как последний шанс.
find_lua_bin() {
    local candidate
    for candidate in lua lua5.1 lua5.3 lua5.4 \
        /opt/bin/lua /opt/bin/lua5.1 /opt/usr/bin/lua /usr/bin/lua /usr/local/bin/lua; do
        if command -v "$candidate" >/dev/null 2>&1; then
            command -v "$candidate"
            return 0
        fi
    done
    if lua -v >/dev/null 2>&1; then
        echo "lua"
        return 0
    fi
    return 1
}

check_dependencies() {
    LUA_BIN=$(find_lua_bin)
    if [ -z "$LUA_BIN" ]; then
        echo -e "${RED}[FATAL] Интерпретатор lua не найден ни в PATH, ни по стандартным путям Entware.${RESET}"
        echo -e "${YELLOW}[HINT] Если 'lua' работает в интерактивном шелле - узнайте его реальный путь через 'command -v lua' там же и пропишите его напрямую в переменной LUA_BIN в начале скрипта.${RESET}"
        return 1
    fi
    if [ ! -f "$WORKDIR/converter.lua" ]; then
        echo -e "${RED}[FATAL] $WORKDIR/converter.lua не найден.${RESET}"
        return 1
    fi
    return 0
}

check_disk_space || exit 1
check_dependencies || exit 1

# =====================================================================
# ФУНКЦИИ УПРАВЛЕНИЯ ПРОЦЕССАМИ
# =====================================================================

# Убивает все ТЕСТОВЫЕ (не main) sing-box процессы, связанные с $TEMP.
# Проверяет реальный cmdline через /proc, а не полагается на формат
# вывода `ps` (на урезанном busybox он часто без полных аргументов).
kill_testers() {
    [ -n "$TEST_PID" ] && kill -9 "$TEST_PID" 2>/dev/null
    for p in $(pidof sing-box 2>/dev/null); do
        if cat /proc/$p/cmdline 2>/dev/null | tr '\0' ' ' | grep -qE "$TEMP/(run|run_entry|run_fast)\.json"; then
            kill -9 $p 2>/dev/null
        fi
    done
    for p in $(ps 2>/dev/null | grep '[s]ing-box' | awk '{print $1}'); do
        if cat /proc/$p/cmdline 2>/dev/null | tr '\0' ' ' | grep -qE "$TEMP/(run|run_entry|run_fast)\.json"; then
            kill -9 $p 2>/dev/null
        fi
    done
    TEST_PID=""
}
kill_testers

stop_main() {
    local target_name
    target_name=$(basename "$CONF_TARGET")
    if [ -f "$MAIN_PIDFILE" ]; then
        MPID=$(cat "$MAIN_PIDFILE")
        if [ -n "$MPID" ] && cat /proc/$MPID/cmdline 2>/dev/null | tr '\0' ' ' | grep -q "sing-box"; then
            kill -9 "$MPID" 2>/dev/null
        fi
        rm -f "$MAIN_PIDFILE"
    fi
    for p in $(pidof sing-box 2>/dev/null); do
        if cat /proc/$p/cmdline 2>/dev/null | tr '\0' ' ' | grep -q "$target_name"; then kill -9 $p 2>/dev/null; fi
    done
    for p in $(ps 2>/dev/null | grep '[s]ing-box' | awk '{print $1}'); do
        if cat /proc/$p/cmdline 2>/dev/null | tr '\0' ' ' | grep -q "$target_name"; then kill -9 $p 2>/dev/null; fi
    done
}

start_main() {
    if [ -f "$MAIN_PIDFILE" ]; then
        MPID=$(cat "$MAIN_PIDFILE")
        if [ -n "$MPID" ] && kill -0 "$MPID" 2>/dev/null && cat /proc/$MPID/cmdline 2>/dev/null | tr '\0' ' ' | grep -q "sing-box"; then
            return 0
        fi
    fi
    "$BIN" run -c "$CONF_TARGET" >> "$LOGFILE" 2>&1 &
    echo $! > "$MAIN_PIDFILE"
}

# Общая функция запуска тестового sing-box + ожидания поднятия Clash API.
# timeout_iters сохраняет ИМЕННО те значения, что были у каждого вызова
# в оригинале (см. вызовы ниже): Fast Check=15, gather_pool=20, chain=25.
start_tester() {
    local cfg="$1"
    local timeout_iters="${2:-20}"
    kill_testers
    "$BIN" run -c "$cfg" >/dev/null 2>&1 &
    TEST_PID=$!
    local i=1
    while [ "$i" -le "$timeout_iters" ]; do
        if curl -s --connect-timeout 2 "http://127.0.0.1:$TEST_API_PORT/proxies" >/dev/null 2>&1; then
            return 0
        fi
        sleep 2
        i=$((i + 1))
    done
    return 1
}

# =====================================================================
# v6: EXIT-TRAP С ЗАЩИТОЙ "RESTART PENDING"
# Если скрипт прервётся ровно между stop_main и start_main в финальной
# сборке (см. секцию FINAL ASSEMBLY), main будет поднят принудительно
# здесь же, а не оставлен выключенным до следующего запуска по крону.
# =====================================================================
RESTART_MARKER=""   # заполняется ниже, после того как известен $TEMP

cleanup_on_exit() {
    kill_testers
    if [ -n "$RESTART_MARKER" ] && [ -f "$RESTART_MARKER" ]; then
        echo -e "${YELLOW}[HYBRID] Обнаружен незавершённый рестарт main - поднимаю обратно.${RESET}" >&2
        start_main
    fi
    rm -rf "$TEMP" 2>/dev/null
}
trap cleanup_on_exit EXIT
trap 'exit 1' INT TERM

check_provider() {
    echo -e "\n${CYAN}[HYBRID] Selecting optimal Speed Test CDN...${RESET}"
    local attempt=1; local wait_time=2
    while [ $attempt -le 5 ]; do
        for U in $TEST_URLS; do
            if curl -k -IsL --connect-timeout 5 "$U" 2>/dev/null | grep -qE "HTTP/.* (200|206)"; then
                ACTIVE_TEST_URL="$U"
                DOMAIN=$(echo "$U" | awk -F/ '{print $3}')
                echo -e "  ${GREEN}➔ Selected CDN: $DOMAIN${RESET}"
                return 0
            fi
        done
        echo -e "  ${YELLOW}[WARN] Connection failed. Retrying...${RESET}"
        sleep $wait_time; wait_time=$((wait_time * 2)); attempt=$((attempt + 1))
    done
    echo -e "${RED}[ERROR] No internet connection or CDNs blocked!${RESET}"
    return 1
}

write_jq_filters() {
    cat << EOF > "$TEMP/gen.jq"
. as \$n | { "log": { "level": "error" }, "experimental": { "clash_api": { "external_controller": "127.0.0.1:$TEST_API_PORT" } }, "route": { "final": "tester_group" }, "inbounds": [ { "type": "socks", "tag": "socks-test", "listen": "127.0.0.1", "listen_port": $TEST_PORT } ], "outbounds": (\$n + [{ "type": "urltest", "tag": "tester_group", "outbounds": (\$n | map(.tag)), "url": "http://cp.cloudflare.com/generate_204", "interval": "1m", "tolerance": 50 }]) }
EOF

    cat << EOF > "$TEMP/gen_chain.jq"
. as \$n | { "log": { "level": "error" }, "experimental": { "clash_api": { "external_controller": "127.0.0.1:$TEST_API_PORT" } }, "route": { "final": "tester_group" }, "inbounds": [ { "type": "socks", "tag": "socks-test", "listen": "127.0.0.1", "listen_port": $TEST_PORT } ], "outbounds": (\$entry[0] + \$n + [{ "type": "urltest", "tag": "tester_group", "outbounds": (\$n | map(.tag)), "url": "http://cp.cloudflare.com/generate_204", "interval": "1m", "tolerance": 50 }]) }
EOF

    cat << EOF > "$TEMP/gen_chain_fast.jq"
. as \$all_nodes | { "log": { "level": "error" }, "experimental": { "clash_api": { "external_controller": "127.0.0.1:$TEST_API_PORT" } }, "route": { "final": "tester_group" }, "inbounds": [ { "type": "socks", "tag": "socks-test", "listen": "127.0.0.1", "listen_port": $TEST_PORT } ], "outbounds": (\$all_nodes + [{ "type": "urltest", "tag": "tester_group", "outbounds": (\$all_nodes | map(select(.detour != null and .detour != "direct" and .detour != "") | .tag)), "url": "http://cp.cloudflare.com/generate_204", "interval": "1m", "tolerance": 50 }]) }
EOF

    cat << EOF > "$TEMP/api_all_valid.jq"
.proxies | to_entries | map(select(.value.history | length > 0) | select(.value.history[-1].delay > 0 and .value.history[-1].delay <= $MAX_ACCEPTABLE_PING) | select(.key != "socks-test" and .key != "tester_group")) | map(.key) | .[]
EOF

    cat << 'EOF' > "$TEMP/uroboros.jq"
def get_prefix(s): (s | split(".")) as $p | if ($p | length) == 4 then $p[0:3] | join(".") else s end;
map(
  select(.tag != $t and .server != $srv and get_prefix(.server) != get_prefix($srv)) |
  .tag = (.tag + "_via_" + $t) |
  .detour = $t
)
EOF

    cat << 'EOF' > "$TEMP/fin.jq"
.log.level = "warn" | .outbounds = $entry[0] + $nodes[0] + $sel[0] + .outbounds | .route.final = "Best-Auto"
EOF

    cat << EOF > "$TEMP/sel.jq"
[{ "type": "urltest", "tag": "Best-Auto", "outbounds": \$tags[0], "url": "http://cp.cloudflare.com/generate_204", "interval": "12m", "tolerance": 150 }]
EOF

    cat << 'EOF' > "$TEMP/dec.lua"
local f = io.open(arg[1], "r")
if not f then os.exit(1) end
local str = f:read("*a"):gsub("[%s%c]", ""):gsub("-", "+"):gsub("_", "/")
f:close()
local b = 'ABCDEFGHIJKLMNOPQRSTUVWXYZabcdefghijklmnopqrstuvwxyz0123456789+/'
local res = {}
for i = 1, #str, 4 do
    local n = 0
    for j = 0, 3 do
        local c = str:sub(i+j, i+j)
        local val = b:find(c, 1, true)
        if val then n = n + (val - 1) * (64^(3-j)) end
    end
    table.insert(res, string.char(math.floor(n / 65536)))
    if str:sub(i+2, i+2) ~= "=" then table.insert(res, string.char(math.floor((n % 65536) / 256))) end
    if str:sub(i+3, i+3) ~= "=" then table.insert(res, string.char(n % 256)) end
end
print(table.concat(res))
EOF
}

prepare_temp() {
    kill_testers && sleep 1
    rm -rf "$TEMP" 2>/dev/null; mkdir -p "$TEMP" || return 1
    RESTART_MARKER="$TEMP/.restart_pending"
    write_jq_filters || return 1

    echo -e "${CYAN}[HYBRID] Shifting inbound ports (+$PORT_SHIFT)...${RESET}"
    nice -n 19 jq --argjson shift "$PORT_SHIFT" '.inbounds |= map(if .listen_port then .listen_port += $shift else . end)' "$CONF_BASE" > "$TEMP/conf_base_shifted.json"
    return 0
}

check_provider || exit 1
prepare_temp || exit 1

# =====================================================================
# FAST-CHAIN CHECK (СТРОГИЙ РЕЖИМ 70%) - таймауты сохранены как в оригинале
# =====================================================================
if [ -s "$CONF_TARGET" ]; then
    echo -e "${CYAN}[HYBRID] Checking existing chains (Fast Check)...${RESET}"
    nice -n 19 jq '[.outbounds[]? | select(.type != "urltest" and .type != "selector" and .type != "direct" and .type != "dns" and .type != "block")]' "$CONF_TARGET" > "$TEMP/fast_nodes.json"
    TOTAL_FAST=$(jq 'length' "$TEMP/fast_nodes.json" 2>/dev/null || echo 0)

    if [ "$TOTAL_FAST" -gt 0 ]; then
        nice -n 19 jq -f "$TEMP/gen_chain_fast.jq" "$TEMP/fast_nodes.json" > "$TEMP/run_fast.json"

        if start_tester "$TEMP/run_fast.json" 15; then
            sleep 5
            STABLE_COUNT=0
            CHECKED_COUNT=0
            STABLE_THRESHOLD=$(( (WANTED_CHAINS * 70 + 50) / 100 ))
            echo -e "  ${PURPLE}Retention Threshold: $STABLE_THRESHOLD chains (70% of $WANTED_CHAINS)${RESET}"

            VALID_NODES=$(curl -s http://127.0.0.1:$TEST_API_PORT/proxies | jq -r -f "$TEMP/api_all_valid.jq")
            for NODE in $VALID_NODES; do
                if [ -n "$NODE" ] && [ "$NODE" != "null" ]; then
                    CHECKED_COUNT=$((CHECKED_COUNT+1))
                    echo -e "  [PING OK] Checking speed for existing chain: $NODE"
                    curl -s -X PUT -d "{\"name\":\"$NODE\"}" "http://127.0.0.1:$TEST_API_PORT/proxies/tester_group" >/dev/null
                    sleep 2
                    SPD=$(curl --socks5-hostname 127.0.0.1:$TEST_PORT -sL -o /dev/null -w "%{speed_download}" --connect-timeout 10 --max-time 15 "$ACTIVE_TEST_URL" 2>/dev/null)
                    KBPS=$(echo "$SPD" | awk '{print int($1 / 1024)}')
                    [ -z "$KBPS" ] && KBPS=0

                    if [ "$KBPS" -ge "$MIN_CHAIN_SPEED_KBPS" ]; then
                        echo -e "  [OK] $NODE : ${GREEN}$KBPS KB/s${RESET}"
                        STABLE_COUNT=$((STABLE_COUNT+1))
                        # v6: реальный ранний выход - как только порога 70%
                        # достаточно, дальше не тестируем оставшиеся ноды.
                        if [ "$STABLE_COUNT" -ge "$STABLE_THRESHOLD" ]; then
                            break
                        fi
                    else
                        echo -e "  [SLOW] $NODE : ${YELLOW}$KBPS KB/s${RESET}"
                    fi
                fi
            done

            if [ "$STABLE_COUNT" -ge "$STABLE_THRESHOLD" ]; then
                echo -e "${GREEN}>>> [OK] Достаточно быстрых цепочек: $STABLE_COUNT/$STABLE_THRESHOLD нужно (проверено $CHECKED_COUNT из $TOTAL_FAST). Aborting full scan.${RESET}"
                kill_testers
                exit 0
            fi
            echo -e "${YELLOW}>>> [WARN] Only $STABLE_COUNT of $CHECKED_COUNT checked chains are fast enough. Forcing full update...${RESET}"
        fi
        kill_testers
    fi
fi

# =====================================================================
# СКАЧИВАНИЕ И УМНАЯ КВОТА ПРОТОКОЛОВ (С Base64 ДЕКОДЕРОМ)
# =====================================================================
echo -e "\n${CYAN}[HYBRID] Starting Proxy Download & Protocol Quota Allocation...${RESET}"
> "$TEMP/all_subs.txt"
for URL in $SUBS_LIST; do
    FNAME=$(basename "$URL")
    echo -n "  ➔ Downloading $FNAME... "
    if curl -k -sL -A "v2rayNG" -o "$TEMP/part.tmp" "$URL"; then
        tr -d '\000\r' < "$TEMP/part.tmp" > "$TEMP/part.txt"

        if ! grep -qE "^(ss|vless|trojan)://" "$TEMP/part.txt" 2>/dev/null; then
            nice -n 19 "$LUA_BIN" "$TEMP/dec.lua" "$TEMP/part.txt" > "$TEMP/part_dec.txt" 2>/dev/null
            if [ -s "$TEMP/part_dec.txt" ] && grep -qE "^(ss|vless|trojan)://" "$TEMP/part_dec.txt" 2>/dev/null; then
                mv "$TEMP/part_dec.txt" "$TEMP/part.txt"
            else
                echo -e "${YELLOW}[WARN] $FNAME: формат не распознан (ни plain, ни base64). Источник пропущен.${RESET}"
            fi
        fi

        LINES_ADDED=$(grep -icE "^(ss|vless|trojan)://" "$TEMP/part.txt" 2>/dev/null || echo 0)
        grep -iE "^(ss|vless|trojan)://" "$TEMP/part.txt" >> "$TEMP/all_subs.txt"
        if [ "${LINES_ADDED:-0}" -eq 0 ] 2>/dev/null; then
            echo -e "${YELLOW}0 нод${RESET}"
        else
            echo -e "${GREEN}OK ($LINES_ADDED нод)${RESET}"
        fi
    else
        echo -e "${RED}Failed!${RESET}"
    fi
    rm -f "$TEMP/part.tmp" "$TEMP/part.txt" "$TEMP/part_dec.txt"
done

echo -e "${CYAN}[HYBRID] Applying deduplication and Protocol Quotas...${RESET}"
grep -iE "^ss://" "$TEMP/all_subs.txt" | awk '!seen[$0]++' | head -n 1200 > "$TEMP/q_ss.txt"
grep -iE "^vless://" "$TEMP/all_subs.txt" | awk '!seen[$0]++' | head -n 800 > "$TEMP/q_vless.txt"
grep -iE "^trojan://" "$TEMP/all_subs.txt" | awk '!seen[$0]++' | head -n 500 > "$TEMP/q_trojan.txt"

cat "$TEMP/q_ss.txt" "$TEMP/q_vless.txt" "$TEMP/q_trojan.txt" > "$WORKDIR/subs_raw.txt"
rm -f "$TEMP/q_ss.txt" "$TEMP/q_vless.txt" "$TEMP/q_trojan.txt" "$TEMP/all_subs.txt"

FILTERED_COUNT=$(wc -l < "$WORKDIR/subs_raw.txt" | tr -d ' ')
echo -e "  ➔ Extracted $FILTERED_COUNT guaranteed unique nodes (1200 SS, 800 VLESS, 500 Trojan)."

echo -n "  ➔ Compiling JSON mapping (Lua)... "
cd "$WORKDIR" || { echo -e "\n${RED}[FATAL] Не удалось перейти в $WORKDIR${RESET}"; exit 1; }
nice -n 19 "$LUA_BIN" converter.lua >/dev/null 2>&1
if [ ! -s "all_nodes.json" ]; then
    echo -e "\n${RED}[ERROR] Converter failed or nodes list is empty. Exiting.${RESET}"
    start_main
    exit 1
fi
echo -e "${GREEN}Done.${RESET}"

# =====================================================================
# v6: ПОСТРОЕНИЕ ПРОТОКОЛЬНОГО ПУЛА (ОДИН РАЗ ЗА ПРОГОН НА ПРОТОКОЛ)
# =====================================================================
build_raw_pool() {
    local proto="$1"
    local out="$TEMP/rawnodes_${proto}.json"
    [ -s "$out" ] && return 0

    case "$ENCRYPTION_PRIORITY" in
        2)
            nice -n 19 jq --arg p "$proto" 'map(select(.type == $p and (
                if .type == "shadowsocks" then .method != "none"
                elif .type == "vless" then (.tls.enabled == true)
                elif .type == "trojan" then (.tls != null and .tls.enabled != false)
                else true end
            )))' all_nodes.json > "$out"
            ;;
        3)
            nice -n 19 jq --arg p "$proto" 'map(select(.type == $p)) | sort_by(
                if (.type == "shadowsocks" and .method == "none") then 1
                elif (.type == "vless" and (.tls.enabled == null or .tls.enabled == false)) then 1
                elif (.type == "trojan" and (.tls == null or .tls.enabled == false)) then 1
                else 0 end
            )' all_nodes.json > "$out"
            ;;
        *)
            nice -n 19 jq --arg p "$proto" 'map(select(.type == $p))' all_nodes.json > "$out"
            ;;
    esac
}

# =====================================================================
# v6: ОБЩАЯ ФУНКЦИЯ СБОРА ПУЛА (кэш по протоколу, не по роли anchor/exit)
# =====================================================================
gather_pool() {
    local proto_json="$1"      # shadowsocks | vless | trojan
    local need="$2"            # ANCHOR_POOL_SIZE или EXIT_POOL_SIZE
    local out_file="$3"        # куда сложить top-N результата (anchor_pool.txt/exit_pool.txt)
    local pool_name="$4"       # только для человекочитаемых логов (ANCHOR/EXIT)

    local pool_file="$TEMP/pool_${proto_json}.txt"
    local raw_file="$TEMP/rawnodes_${proto_json}.json"
    local scanned_file="$TEMP/scanned_${proto_json}"

    touch "$pool_file" "$scanned_file" 2>/dev/null
    local have
    have=$(wc -l < "$pool_file" | tr -d ' ' 2>/dev/null); [ -z "$have" ] && have=0

    if [ "$have" -ge "$need" ]; then
        echo -e "   ${GREEN}[CACHE] Общий пул [$proto_json] уже содержит $have годных нод (нужно $need для $pool_name). Пропускаем сканирование.${RESET}"
    else
        echo -e "\n${CYAN}➔ Collecting shared Pool (Protocol: $proto_json, need: $need for $pool_name, have: $have)...${RESET}"
        build_raw_pool "$proto_json"

        local TOTAL_VALID
        TOTAL_VALID=$(jq 'length' "$raw_file" 2>/dev/null || echo 0)
        local CUR
        CUR=$(cat "$scanned_file" 2>/dev/null); [ -z "$CUR" ] && CUR=0

        while [ "$have" -lt "$need" ] && [ "$CUR" -lt "$TOTAL_VALID" ]; do
            local END=$((CUR + 3))
            [ "$END" -gt "$TOTAL_VALID" ] && END=$TOTAL_VALID

            local TEST_TAGS
            TEST_TAGS=$(nice -n 19 jq -r ".[$CUR:$END][].tag" "$raw_file" | tr '\n' ' ')
            echo -e "${YELLOW}➔ Testing $proto_json Batch $CUR-$END:${RESET}"
            echo -e "   Nodes: $TEST_TAGS"

            nice -n 19 jq ".[$CUR:$END]" "$raw_file" | nice -n 19 jq -f "$TEMP/gen.jq" > "$TEMP/run_entry.json"

            if start_tester "$TEMP/run_entry.json" 20; then
                sleep 4
                local VALID_NODES
                VALID_NODES=$(curl -s http://127.0.0.1:$TEST_API_PORT/proxies | jq -r -f "$TEMP/api_all_valid.jq")
                for NODE in $VALID_NODES; do
                    if [ -n "$NODE" ] && [ "$NODE" != "null" ]; then
                        echo -e "   [PING OK] Checking speed for: $NODE"
                        curl -s -X PUT -d "{\"name\":\"$NODE\"}" "http://127.0.0.1:$TEST_API_PORT/proxies/tester_group" >/dev/null
                        sleep 2
                        local SPD CODE KBPS
                        SPD=$(curl --socks5-hostname 127.0.0.1:$TEST_PORT -sL -o /dev/null -w "%{http_code}|%{speed_download}" --connect-timeout 10 --max-time 20 "$ACTIVE_TEST_URL" 2>/dev/null)
                        CODE=$(echo "$SPD" | cut -d'|' -f1)
                        KBPS=$(echo "$SPD" | cut -d'|' -f2 | awk '{print int($1 / 1024)}')
                        [ -z "$KBPS" ] && KBPS=0

                        if [ "$CODE" = "200" ] || [ "$CODE" = "206" ]; then
                            if [ "$KBPS" -ge "$MIN_POOL_SPEED_KBPS" ]; then
                                echo -e "   ${GREEN}[POOL ADMIT] $NODE : $KBPS KB/s${RESET}"
                                echo "$KBPS|$NODE" >> "$pool_file"
                                have=$((have + 1))
                                if [ "$have" -ge "$need" ]; then break; fi
                            else
                                echo -e "   ${YELLOW}[POOL LOW] Code: $CODE, Speed: $KBPS KB/s (Requires $MIN_POOL_SPEED_KBPS)${RESET}"
                            fi
                        else
                            echo -e "   ${RED}[POOL FAIL] Code: $CODE, Speed: $KBPS KB/s${RESET}"
                        fi
                    fi
                done
            fi
            CUR=$END
            echo "$CUR" > "$scanned_file"
        done
        kill_testers
    fi

    if [ "$have" -lt 1 ]; then return 1; fi
    sort -rn "$pool_file" | awk -F"|" '!seen[$2]++' | head -n "$need" > "$out_file"
    return 0
}

# =====================================================================
# MAIN PIPELINE
# =====================================================================
for CHAIN_TYPE in $CHAIN_TYPES; do
    echo -e "\n${PURPLE}==================================================${RESET}"
    echo -e "${PURPLE}>>> ATTEMPTING TO BUILD HYBRID CHAIN: [ $CHAIN_TYPE ]${RESET}"
    echo -e "${PURPLE}==================================================${RESET}"

    > "$TEMP/chain_results.txt"

    P_ENTRY=$(echo "$CHAIN_TYPE" | cut -d'-' -f1)
    P_EXIT=$(echo "$CHAIN_TYPE" | cut -d'-' -f2)

    [ "$P_ENTRY" = "ss" ] && JSON_ENTRY="shadowsocks" || JSON_ENTRY="$P_ENTRY"
    [ "$P_EXIT" = "ss" ] && JSON_EXIT="shadowsocks" || JSON_EXIT="$P_EXIT"

    if ! gather_pool "$JSON_ENTRY" "$ANCHOR_POOL_SIZE" "$TEMP/anchor_pool.txt" "ANCHOR"; then
        echo -e "  ${YELLOW}[SKIP] Failed to gather Anchor pool for $CHAIN_TYPE.${RESET}"
        continue
    fi

    if ! gather_pool "$JSON_EXIT" "$EXIT_POOL_SIZE" "$TEMP/exit_pool.txt" "EXIT"; then
        echo -e "  ${YELLOW}[SKIP] Failed to gather Exit pool for $CHAIN_TYPE.${RESET}"
        continue
    fi

    sort -rn "$TEMP/anchor_pool.txt" | awk -F"|" '!seen[$2]++' | cut -d"|" -f2 > "$TEMP/anchor_tags.txt"
    nice -n 19 jq -Rs 'split("\n") | map(select(length > 0))' "$TEMP/anchor_tags.txt" > "$TEMP/a_tags.json"
    nice -n 19 jq --slurpfile tags "$TEMP/a_tags.json" 'map(. as $n | select($tags[0] | index($n.tag)))' "$TEMP/rawnodes_${JSON_ENTRY}.json" > "$TEMP/anchors.json"

    sort -rn "$TEMP/exit_pool.txt" | awk -F"|" '!seen[$2]++' | cut -d"|" -f2 > "$TEMP/exit_tags.txt"
    nice -n 19 jq -Rs 'split("\n") | map(select(length > 0))' "$TEMP/exit_tags.txt" > "$TEMP/e_tags.json"
    nice -n 19 jq --slurpfile tags "$TEMP/e_tags.json" 'map(. as $n | select($tags[0] | index($n.tag)))' "$TEMP/rawnodes_${JSON_EXIT}.json" > "$TEMP/exits.json"

    for ANCHOR_TAG in $(cat "$TEMP/anchor_tags.txt"); do
        echo -e "${CYAN}➔ Cross-Breeding via Anchor: $ANCHOR_TAG${RESET}"

        nice -n 19 jq --arg t "$ANCHOR_TAG" '[.[] | select(.tag == $t)]' "$TEMP/anchors.json" > "$TEMP/current_entry.json"
        ANCHOR_SERVER=$(jq -r --arg t "$ANCHOR_TAG" '.[] | select(.tag == $t) | .server' "$TEMP/anchors.json")

        nice -n 19 jq --arg t "$ANCHOR_TAG" --arg srv "$ANCHOR_SERVER" -f "$TEMP/uroboros.jq" "$TEMP/exits.json" > "$TEMP/current_matrix.json"

        MAT_LEN=$(jq 'length' "$TEMP/current_matrix.json" 2>/dev/null || echo 0)
        if [ "$MAT_LEN" -lt 1 ]; then
            echo -e "   ${YELLOW}[ANCHOR SKIP] Matrix empty. Uroboros filtered all exits for this anchor.${RESET}"
            continue
        fi

        nice -n 19 jq --slurpfile entry "$TEMP/current_entry.json" -f "$TEMP/gen_chain.jq" "$TEMP/current_matrix.json" > "$TEMP/run.json"

        if ! "$BIN" check -c "$TEMP/run.json" >/dev/null 2>&1; then
            echo -e "   ${RED}[ANCHOR SKIP] Invalid config generated.${RESET}"
            continue
        fi

        if start_tester "$TEMP/run.json" 25; then
            sleep 5
            VALID_NODES=$(curl -s http://127.0.0.1:$TEST_API_PORT/proxies | jq -r -f "$TEMP/api_all_valid.jq")
            for CHAIN_NODE in $VALID_NODES; do
                if [ -n "$CHAIN_NODE" ] && [ "$CHAIN_NODE" != "null" ]; then
                    echo -e "   [PING OK] Checking chain speed: $CHAIN_NODE"
                    curl -s -X PUT -d "{\"name\":\"$CHAIN_NODE\"}" "http://127.0.0.1:$TEST_API_PORT/proxies/tester_group" >/dev/null
                    sleep 3
                    SPD=$(curl --socks5-hostname 127.0.0.1:$TEST_PORT -sL -o /dev/null -w "%{http_code}|%{speed_download}" --connect-timeout 20 --max-time 40 "$ACTIVE_TEST_URL" 2>/dev/null)
                    CODE=$(echo "$SPD" | cut -d'|' -f1)
                    KBPS=$(echo "$SPD" | cut -d'|' -f2 | awk '{print int($1 / 1024)}')
                    [ -z "$KBPS" ] && KBPS=0

                    if [ "$CODE" = "200" ] || [ "$CODE" = "206" ]; then
                        if [ "$KBPS" -ge "$MIN_CHAIN_SPEED_KBPS" ]; then
                            echo -e "   ${GREEN}[CHAIN SUCCESS] $CHAIN_NODE : $KBPS KB/s${RESET}"
                            echo "$KBPS|$CHAIN_NODE" >> "$TEMP/chain_results.txt"
                            FOUND_CHAINS=$(wc -l < "$TEMP/chain_results.txt" | tr -d ' ' 2>/dev/null || echo 0)
                            if [ "$FOUND_CHAINS" -ge "$WANTED_CHAINS" ]; then
                                break 3
                            fi
                        else
                            echo -e "   ${YELLOW}[CHAIN SLOW] Code: $CODE, Speed: $KBPS KB/s (Requires $MIN_CHAIN_SPEED_KBPS)${RESET}"
                        fi
                    else
                        echo -e "   ${RED}[CHAIN FAIL] Code: $CODE, Speed: $KBPS KB/s${RESET}"
                    fi
                fi
            done
        fi
    done

    FOUND_CHAINS=$(wc -l < "$TEMP/chain_results.txt" | tr -d ' ' 2>/dev/null || echo 0)
    if [ "$FOUND_CHAINS" -ge "$WANTED_CHAINS" ]; then
        echo -e "${GREEN}>>> Success! Built enough chains for [$CHAIN_TYPE]!${RESET}"
        break
    fi
done

kill_testers

# =====================================================================
# FINAL ASSEMBLY
# =====================================================================
if [ -s "$TEMP/chain_results.txt" ]; then
    echo -e "\n${CYAN}[HYBRID] Assembling Multi-Hop Configuration...${RESET}"

    sort -rn "$TEMP/chain_results.txt" | awk -F"|" '!seen[$2]++' | head -n $WANTED_CHAINS | cut -d"|" -f2 > "$TEMP/top_chains.txt"
    nice -n 19 jq -Rs 'split("\n") | map(select(length > 0))' "$TEMP/top_chains.txt" > "$TEMP/chain_tags.json"

    > "$TEMP/giant_matrix.json"
    for A_TAG in $(cat "$TEMP/anchor_tags.txt"); do
        A_SRV=$(jq -r --arg t "$A_TAG" '.[] | select(.tag == $t) | .server' "$TEMP/anchors.json")
        nice -n 19 jq --arg t "$A_TAG" --arg srv "$A_SRV" -f "$TEMP/uroboros.jq" "$TEMP/exits.json" >> "$TEMP/giant_matrix.json"
    done
    nice -n 19 jq -s 'flatten' "$TEMP/giant_matrix.json" > "$TEMP/flat_matrix.json"
    nice -n 19 jq --slurpfile tags "$TEMP/chain_tags.json" 'map(. as $n | select($tags[0] | index($n.tag)))' "$TEMP/flat_matrix.json" > "$TEMP/final_chains.json"

    nice -n 19 jq 'map(.detour) | unique' "$TEMP/final_chains.json" > "$TEMP/used_anchors.json"
    nice -n 19 jq --slurpfile anchors "$TEMP/used_anchors.json" 'map(. as $n | select($anchors[0] | index($n.tag)))' "$TEMP/anchors.json" > "$TEMP/final_entries.json"

    nice -n 19 jq "map(.tag)" "$TEMP/final_chains.json" > "$TEMP/ftags.json"
    nice -n 19 jq -n --slurpfile tags "$TEMP/ftags.json" -f "$TEMP/sel.jq" > "$TEMP/sel.json"

    nice -n 19 jq --slurpfile nodes "$TEMP/final_chains.json" \
                  --slurpfile entry "$TEMP/final_entries.json" \
                  --slurpfile sel "$TEMP/sel.json" \
                  -f "$TEMP/fin.jq" "$TEMP/conf_base_shifted.json" > "$TEMP/conf_target_candidate.json"

    # v6: обязательная валидация готового конфига перед тем, как класть его
    # на место боевого и перезапускать сервис.
    if ! "$BIN" check -c "$TEMP/conf_target_candidate.json" >/dev/null 2>&1; then
        echo -e "${RED}[FATAL] Итоговый конфиг не прошёл проверку sing-box check! Main НЕ перезапускается, старый конфиг остаётся в силе.${RESET}"
    else
        cp "$TEMP/conf_target_candidate.json" "$CONF_TARGET"
        echo -e "${CYAN}[HYBRID] Starting Hybrid Proxy Server...${RESET}"

        # v6: помечаем начало окна "рестарт в процессе" - если скрипт
        # прервётся здесь, EXIT-trap обязательно вызовет start_main.
        touch "$RESTART_MARKER"
        stop_main
        sleep 1
        start_main
        rm -f "$RESTART_MARKER"

        echo -e "${GREEN}[HYBRID] DONE! Server is running on ports $((20081+PORT_SHIFT))-$((20085+PORT_SHIFT)). Config saved to $(basename "$CONF_TARGET").${RESET}"
    fi
else
    echo -e "${RED}[ERROR] Failed to build enough fast chains. Try running again later.${RESET}"
fi

rm -f "$WORKDIR/subs_raw.txt" "$WORKDIR/all_nodes.json" 2>/dev/null
# $TEMP удаляется в EXIT-trap (cleanup_on_exit) - не дублируем здесь.
