#!/bin/sh
# =================================================================================
# Cross-Protocol Breeder - Smart Installer v4.4 (Entware / Side-by-Side Edition)
# =================================================================================

set -u
LC_ALL=C
LANG=C

GREEN='\033[1;32m'; RED='\033[1;31m'; YELLOW='\033[1;33m'
CYAN='\033[1;36m'; DIM='\033[2m'; RESET='\033[0m'

SB_VERSION="1.13.14-extended-2.5.2"
REPO_RAW="https://raw.githubusercontent.com/Sophiedevops/cross-protocol-breeder/main"
BINARY_BASE="https://github.com/Sophiedevops/cross-protocol-breeder/releases/download/Binary"

FINAL_DIR="/opt/sb-breeder"
FINAL_BIN="$FINAL_DIR/sb-breeder"
WORKDIR=""

# ----------------------------------------------------------------------------
# ОЧИСТКА ПРИ ПРЕРЫВАНИИ
# ----------------------------------------------------------------------------
cleanup() {
    if [ -n "$WORKDIR" ] && [ -d "$WORKDIR" ]; then
        rm -rf "$WORKDIR" 2>/dev/null
    fi
}
trap 'echo -e "\n${RED}❌ Установка прервана. Очистка...${RESET}"; cleanup; exit 1' HUP INT QUIT TERM

# ----------------------------------------------------------------------------
# УТИЛИТЫ ВЫВОДА И ПРОВЕРКИ
# ----------------------------------------------------------------------------
log()  { echo -e "$@"; }
ok()   { log "  ${GREEN}✅ $*${RESET}"; }
warn() { log "  ${YELLOW}⚠ $*${RESET}" >&2; }
err()  { log "  ${RED}❌ $*${RESET}" >&2; }
info() { log "  ${CYAN}ℹ $*${RESET}"; }

check_cmd() {
    if which "$1" >/dev/null 2>&1; then return 0; fi
    if command -v "$1" >/dev/null 2>&1; then return 0; fi
    if [ -x "/opt/bin/$1" ] || [ -x "/opt/usr/bin/$1" ]; then return 0; fi
    return 1
}

get_cmd_path() {
    local p
    p=$(which "$1" 2>/dev/null)
    [ -z "$p" ] && p=$(command -v "$1" 2>/dev/null)
    [ -z "$p" ] && [ -x "/opt/bin/$1" ] && p="/opt/bin/$1"
    [ -z "$p" ] && echo "$1" || echo "$p"
}

# ----------------------------------------------------------------------------
# FETCH_URL (Безопасный каскадный загрузчик)
# ----------------------------------------------------------------------------
fetch_url() {
    local url="$1" out="$2" max="${3:-90}"
    [ -z "$url" ] || [ -z "$out" ] && return 1
    
    # 1. GNU wget
    if wget --version 2>&1 | grep -q "GNU Wget"; then
        wget -q --timeout="$max" --tries=2 -O "$out" "$url" 2>/dev/null
        if [ $? -eq 0 ] && [ -s "$out" ]; then return 0; fi
        rm -f "$out" 2>/dev/null
    fi
    
    # 2. curl
    if curl --version 2>&1 | grep -q "curl"; then
        curl -k -L -f -s -m "$max" --connect-timeout 30 -o "$out" "$url" 2>/dev/null
        if [ $? -eq 0 ] && [ -s "$out" ]; then return 0; fi
        rm -f "$out" 2>/dev/null
    fi

    # 3. BusyBox wget (fallback)
    if wget --help 2>&1 | grep -q "BusyBox"; then
        wget --no-check-certificate -O "$out" "$url" 2>/dev/null
        if [ $? -eq 0 ] && [ -s "$out" ]; then return 0; fi
        rm -f "$out" 2>/dev/null
    fi
    
    return 1
}

# ----------------------------------------------------------------------------
# ЭВРИСТИКА ДЕТЕКТИРОВАНИЯ
# ----------------------------------------------------------------------------
detect_endian() {
    if check_cmd lscpu; then
        local o; o=$(lscpu 2>/dev/null | grep -i "byte order" | awk '{print tolower($NF)}' | tr -d ' \t\n')
        case "$o" in little) echo "le"; return ;; big) echo "be"; return ;; esac
    fi
    
    if check_cmd getconf; then
        local bo; bo=$(getconf BYTE_ORDER 2>/dev/null | tr -d ' \t\n')
        case "$bo" in *LITTLE*|*1234*) echo "le"; return ;; *BIG*|*4321*) echo "be"; return ;; esac
    fi
    
    if [ -r /proc/cpuinfo ]; then
        grep -qiE "little.endian|\(LE\)" /proc/cpuinfo 2>/dev/null && { echo "le"; return; }
        grep -qiE "big.endian|\(BE\)" /proc/cpuinfo 2>/dev/null && { echo "be"; return; }
        
        local soc; soc=$(grep -m1 "system type" /proc/cpuinfo 2>/dev/null | sed -E 's/.*:\s*//')
        case "$soc" in
            *MT7621*|*MT7620*|*MT7628*|*RT3052*|*AR9331*|*QCA9531*|*IPQ40xx*|*MediaTek*|*Atheros*) echo "le"; return ;;
            *BCM63xx*|*Cavium*|*Octeon*) echo "be"; return ;;
        esac
    fi
    
    local tf="/tmp/.endian_$$_$RANDOM"
    if printf '\x12\x34' > "$tf" 2>/dev/null; then
        local fb; fb=$(od -An -tx1 "$tf" 2>/dev/null | awk '{print $1}' | tr -d ' \t\n')
        rm -f "$tf"
        case "$fb" in 12) echo "be"; return ;; 34) echo "le"; return ;; esac
    fi
    echo "unknown"
}

detect_arch_raw() {
    local arch=""
    if [ -f /etc/os-release ]; then
        arch=$(grep -E "^OPENWRT_ARCH=" /etc/os-release 2>/dev/null | head -1 | cut -d= -f2 | tr -d '"')
        [ -n "$arch" ] && { echo "openwrt:$arch"; return; }
    fi
    
    local opkg_path
    opkg_path=$(get_cmd_path opkg)
    if [ -x "$opkg_path" ]; then
        arch=$("$opkg_path" print-architecture 2>/dev/null | sort -k3 -nr | awk '$2 != "all" && $2 != "noarch" {print $2; exit}')
    fi
    
    [ -z "$arch" ] && arch=$(uname -m 2>/dev/null)
    
    if [ -z "$arch" ] || [ "$arch" = "unknown" ]; then
        if [ -r /proc/cpuinfo ]; then
            arch=$(grep -m1 -E "^(Hardware|machine|system type|cpu model)" /proc/cpuinfo 2>/dev/null | sed -E 's/.*:\s*//')
        fi
    fi
    echo "$arch"
}

detect_libc() {
    local p
    for p in /lib /usr/lib /lib64 /usr/lib64 /opt/lib /opt/usr/lib; do
        [ -d "$p" ] || continue
        if ls "$p"/ld-musl-* >/dev/null 2>&1; then echo "musl"; return; fi
        if ls "$p"/ld-uClibc-* >/dev/null 2>&1; then echo "uclibc"; return; fi
        if ls "$p"/ld-linux-* >/dev/null 2>&1; then echo "glibc"; return; fi
    done
    
    if check_cmd ldd; then
        local v; v=$(ldd --version 2>&1 | head -1)
        echo "$v" | grep -qi musl && { echo "musl"; return; }
        echo "$v" | grep -qi uClibc && { echo "uclibc"; return; }
        echo "$v" | grep -qi glibc && { echo "glibc"; return; }
    fi
    echo "unknown"
}

build_candidates() {
    local raw="$1" endian="$2" libc="$3" candidates=""
    local base="unknown"
    
    case "$raw" in
        *aarch64*|*arm64*) base="aarch64" ;;
        *armv7*|*cortex-a9*|*arm*) base="armv7" ;;
        *mipsel*|*mipsle*) base="mipsel" ;;
        *mips*)
            if [ "$endian" = "le" ]; then base="mipsel"
            elif [ "$endian" = "be" ]; then base="mips"
            else base="undetermined"; fi
            ;;
        *riscv64*) base="riscv64" ;;
        *loongarch64*) base="loongarch64" ;;
    esac
    
    case "$base" in
        aarch64) candidates="linux-arm64-musl linux-arm64 linux-arm64-glibc linux-arm64-purego" ;;
        armv7) candidates="linux-armv7-musl linux-armv7 linux-armv7-glibc" ;;
        mipsel) candidates="linux-mipsle linux-mipsle-softfloat" ;;
        mips) candidates="linux-mips linux-mips-softfloat" ;;
        riscv64) candidates="linux-riscv64-musl linux-riscv64 linux-riscv64-glibc" ;;
        loongarch64) candidates="linux-loong64-glibc linux-loong64-musl" ;;
        undetermined) err "Не удалось определить порядок байтов (Endianness) для MIPS. Прерывание."; exit 1 ;;
        *) err "Неподдерживаемая или неизвестная архитектура: $raw ($base)"; exit 1 ;;
    esac
    echo "$candidates"
}

# ============================================================================
# MAIN
# ============================================================================
log "${CYAN}================================================================${RESET}"
log "${CYAN}  Cross-Protocol Breeder — Smart Installer v4.4                ${RESET}"
log "${CYAN}================================================================${RESET}"

# === [1/6] Базовые проверки окружения (Entware) ============================
log "\n${YELLOW}[1/6] Проверка среды и зависимостей${RESET}"

if ! ping -c 1 -W 3 github.com >/dev/null 2>&1; then
    err "Отсутствует подключение к интернету или не работает DNS (github.com недоступен)."
    exit 1
fi
ok "Интернет-соединение активно."

OPKG_BIN=$(get_cmd_path opkg)
if [ ! -x "$OPKG_BIN" ]; then
    err "Установка требует полноценную среду Entware и пакетный менеджер opkg!"
    exit 1
fi

fk=$(df -k /opt 2>/dev/null | awk 'NR==2 {print $4}' | tr -d ' ')
if [ -z "$fk" ] || [ "$fk" -lt 102400 ] 2>/dev/null; then
    err "Недостаточно места в /opt. Требуется минимум 100 МБ (свободно: ${fk:-0} KB)"
    exit 1
fi

fs_type=$(df -T /opt 2>/dev/null | awk 'NR==2 {print $2}')
[ -z "$fs_type" ] && fs_type=$(mount 2>/dev/null | grep -E "on /opt " | awk '{print $5}')
case "$fs_type" in
    vfat|fat|fat32|exfat)
        err "Файловая система /opt ($fs_type) не поддерживает права выполнения Linux."
        err "Продолжение установки невозможно."
        exit 1
        ;;
esac

ok "Место в /opt: ${fk} KB свободно (ФС: ${fs_type:-ok})"

MISSING=""
for tool in jq openssl lua; do
    if ! check_cmd "$tool"; then
        MISSING="$MISSING $tool"
    fi
done

if [ -n "$MISSING" ]; then
    err "Отсутствуют обязательные утилиты Entware:$MISSING"
    err "Выполните установку: $OPKG_BIN update && $OPKG_BIN install$MISSING"
    exit 1
fi
ok "Все зависимости установлены."

# === [2/6] Детектирование системы =========================================
log "\n${YELLOW}[2/6] Определение системы${RESET}"

ENDIAN=$(detect_endian); ok "Endianness: $ENDIAN"
ARCH_RAW=$(detect_arch_raw); ok "Архитектура: $ARCH_RAW"
LIBC=$(detect_libc); ok "libc: $LIBC"

CANDIDATES=$(build_candidates "$ARCH_RAW" "$ENDIAN" "$LIBC")

# === [3/6] Скачивание и валидация =========================================
log "\n${YELLOW}[3/6] Загрузка ядра (Side-by-Side)${RESET}"

WORKDIR="/opt/.staging_$$"
mkdir -p "$WORKDIR" || { err "Ошибка создания $WORKDIR"; exit 1; }
cd "$WORKDIR" || exit 1

INSTALLED=0
for cand in $CANDIDATES; do
    fname="sing-box-${SB_VERSION}-${cand}.tar.gz"
    dest="${WORKDIR}/${fname}"
    info "Пробую кандидата: $cand"
    
    if fetch_url "${BINARY_BASE}/${fname}" "$dest" 120; then
        if gzip -t "$dest" >/dev/null 2>&1; then
            ok "Скачано и проверено: $fname"
            tar -xzf "$dest" 2>/dev/null
            ext_dir=$(find . -mindepth 1 -maxdepth 1 -type d 2>/dev/null | head -1)
            if [ -n "$ext_dir" ] && [ -f "$ext_dir/sing-box" ]; then
                mv "$ext_dir/sing-box" "$WORKDIR/sb-breeder"
                chmod +x "$WORKDIR/sb-breeder"
                if "$WORKDIR/sb-breeder" version >/dev/null 2>&1; then
                    INSTALLED=1
                    break
                fi
            fi
        fi
    fi
    rm -rf "$WORKDIR"/* 2>/dev/null
done

if [ "$INSTALLED" -ne 1 ]; then
    err "Не удалось скачать или запустить ни одного кандидата."
    cleanup
    exit 1
fi

# === [4/6] Установка в изолированное окружение ============================
log "\n${YELLOW}[4/6] Изолированная установка${RESET}"

if [ -d "$FINAL_DIR" ]; then
    BACKUP_DIR="${FINAL_DIR}_backup_$(date +%Y%m%d_%H%M%S)"
    warn "Существующая установка → бэкап: $BACKUP_DIR"
    mv "$FINAL_DIR" "$BACKUP_DIR"
fi

mkdir -p "$FINAL_DIR"
cp "$WORKDIR/sb-breeder" "$FINAL_BIN"
cleanup
WORKDIR="$FINAL_DIR"
cd "$FINAL_DIR" || exit 1
ok "Установлено в: $FINAL_DIR"

for f in update_hybrid.sh converter.lua conf3_final.json gen_links.sh; do
    if fetch_url "$REPO_RAW/$f" "$f" 60; then
        ok "Загружен $f"
    else
        err "Ошибка загрузки $f"
        exit 1
    fi
done
chmod +x update_hybrid.sh gen_links.sh

# === [5/6] Генерация сертификатов и конфига ===============================
log "\n${YELLOW}[5/6] Настройка криптографии${RESET}"

CERT_DIR="$FINAL_DIR/certs/grpc"
mkdir -p "$CERT_DIR"

OPENSSL_BIN=$(get_cmd_path openssl)
JQ_BIN=$(get_cmd_path jq)

$OPENSSL_BIN ecparam -genkey -name prime256v1 -out "$CERT_DIR/h2.pem" 2>/dev/null
$OPENSSL_BIN req -new -x509 -days 36500 -key "$CERT_DIR/h2.pem" -out "$CERT_DIR/h2.cert" -subj "/CN=cloudflare.com" 2>/dev/null

SS_PASS=$($OPENSSL_BIN rand -hex 12)
HY2_PASS=$($OPENSSL_BIN rand -hex 10)

$JQ_BIN --arg sp "$SS_PASS" --arg hp "$HY2_PASS" '
    (.inbounds[]? | select(.tag == "ss-in")  | .password) = $sp |
    (.inbounds[]? | select(.tag == "hy2-in") | .users[0].password) = $hp
' conf3_final.json > tmp.json && mv tmp.json conf3_final.json
ok "Конфигурация, сертификаты и пароли успешно созданы"

# === [6/6] Интеграция автозапуска и Cron ==================================
log "\n${YELLOW}[6/6] Интеграция в службы Entware${RESET}"

INIT_FILE="/opt/etc/init.d/S99sb_breeder"
cat << EOF > "$INIT_FILE"
#!/bin/sh
NAME="sb-breeder"
BIN="$FINAL_BIN"
DIR="$FINAL_DIR"
CONF="\$DIR/conf_chain6.json"
PIDFILE="/opt/var/run/\$NAME.pid"

start() {
    echo "Starting \$NAME..."
    nohup \$BIN run -c \$CONF >/dev/null 2>&1 &
    echo \$! > \$PIDFILE
}
stop() {
    echo "Stopping \$NAME..."
    [ -f "\$PIDFILE" ] && kill \$(cat \$PIDFILE) 2>/dev/null
    rm -f \$PIDFILE
}
case "\$1" in
    start) start ;;
    stop) stop ;;
    restart) stop; sleep 2; start ;;
    *) echo "Usage: \$0 {start|stop|restart}" ;;
esac
EOF
chmod +x "$INIT_FILE"
ok "Демон создан: $INIT_FILE"

CRON_F="/opt/etc/crontab"
if [ -f "$CRON_F" ]; then
    sed -i '/# --- CROSS-PROTOCOL BREEDER START ---/,/# --- CROSS-PROTOCOL BREEDER END ---/d' "$CRON_F" 2>/dev/null
else
    touch "$CRON_F" 2>/dev/null
fi

echo "# --- CROSS-PROTOCOL BREEDER START ---" >> "$CRON_F"
echo "0 4 */3 * * root $FINAL_DIR/update_hybrid.sh >/dev/null 2>&1" >> "$CRON_F"
echo "# --- CROSS-PROTOCOL BREEDER END ---" >> "$CRON_F"
/opt/etc/init.d/S10cron restart 2>/dev/null
ok "Cron задача обновлена"

# === ИТОГ ==================================================================
log "\n${CYAN}================================================================${RESET}"
log "${GREEN}  ✅ Установка успешно завершена! (Entware Edition)${RESET}"
log "${CYAN}================================================================${RESET}"
log "Исполняемый файл: ${YELLOW}$FINAL_BIN${RESET}"
log "Каталог данных:   ${YELLOW}$FINAL_DIR${RESET}"
log "Управление:       ${YELLOW}$INIT_FILE {start|stop|restart}${RESET}"
log "\nГенерирую ссылки и запускаю обновление..."

./gen_links.sh 2>/dev/null
sleep 3
./update_hybrid.sh
