#!/bin/sh
# =================================================================================
# Cross-Protocol Breeder - Smart Installer v3.4 (Padavan BusyBox-friendly)
# =================================================================================
# КЛЮЧЕВЫЕ ИЗМЕНЕНИЯ:
#   1. command -v заменён на прямой запуск с обработкой ошибок
#   2. fetch_url использует минимум опций для совместимости с BusyBox
#   3. Убран -f из curl (BusyBox его не поддерживает!)
#   4. Добавлен BUSYBOX-ONLY mode (только через /bin/busybox wget)
#   5. Manifest опционален, SHA256 опциональна (если ничего нет — пропускаем)
#   6. Все проверки делаются мягко — лучше попробовать, чем отказать
#   7. [v3.4] Убрано угадывание endianness при uname=mips: если LE/BE не
#      определены однозначно, установка ОСТАНАВЛИВАЕТСЯ до скачивания
#      каких-либо файлов (см. abort_unknown_endian) — вместо тихого
#      дефолта на BE, который был неверен для подавляющего большинства
#      реальных Padavan-роутеров (MT7620/MT7621/RT3052 и т.п., все LE).
# =================================================================================

set -u
LC_ALL=C
LANG=C

GREEN='\033[1;32m'; RED='\033[1;31m'; YELLOW='\033[1;33m'
CYAN='\033[1;36m'; DIM='\033[2m'; RESET='\033[0m'

SB_VERSION="1.13.14-extended-2.5.2"
REPO_RAW="https://raw.githubusercontent.com/Sophiedevops/cross-protocol-breeder/main"
BINARY_BASE="https://github.com/Sophiedevops/cross-protocol-breeder/releases/download/Binary"
MANIFEST_URL="${BINARY_BASE}/MANIFEST.txt"
API_URL="https://api.github.com/repos/shtorm-7/sing-box-extended/releases/tags/v${SB_VERSION}"

# Состояние
WORKDIR="" BACKUP_DIR="" BACKUP_PERFORMED=0
USE_COMPRESSED=0 INSTALL_ROOT="" SELECTED_PKG_TYPE=""
MANIFEST_LOCAL=""

# ----------------------------------------------------------------------------
# УТИЛИТЫ ВЫВОДА
# ----------------------------------------------------------------------------
log()  { echo -e "$@"; }
ok()   { log "  ${GREEN}✅ $*${RESET}"; }
warn() { log "  ${YELLOW}⚠ $*${RESET}" >&2; }
err()  { log "  ${RED}❌ $*${RESET}" >&2; }
info() { log "  ${CYAN}ℹ $*${RESET}"; }
dbg()  { log "  ${DIM}→ $*${RESET}" >&2; }

# ----------------------------------------------------------------------------
# УТИЛИТЫ ФАЙЛОВОЙ СИСТЕМЫ
# ----------------------------------------------------------------------------
get_free_kb()      { df -k "$1" 2>/dev/null | awk 'NR==2 {print $4}' | tr -d ' '; }
get_file_size_kb() { [ -f "$1" ] && ls -l "$1" 2>/dev/null | awk '{print int(($5+1023)/1024)}' || echo 0; }

calc_sha256() {
    if command -v sha256sum >/dev/null 2>&1; then
        sha256sum "$1" 2>/dev/null | awk '{print $1}'
    elif command -v openssl >/dev/null 2>&1; then
        openssl dgst -sha256 -r "$1" 2>/dev/null | awk '{print $1}'
    else
        echo ""
    fi
}

# ----------------------------------------------------------------------------
# УТИЛИТЫ ПРОВЕРКИ ДОСТУПНОСТИ ИНСТРУМЕНТОВ (Padavan-safe)
# ----------------------------------------------------------------------------

# Проверка: есть ли реально работающий инструмент
# Делаем МЯГКУЮ проверку через прямой запуск
has_tool() {
    local tool="$1"
    
    # Способ 1: type/which
    type "$tool" >/dev/null 2>&1 && return 0
    # Способ 2: command -v
    command -v "$tool" >/dev/null 2>&1 && return 0
    # Способ 3: which
    which "$tool" >/dev/null 2>&1 && return 0
    # Способ 4: прямой запуск (для BusyBox)
    case "$tool" in
        wget) wget --help >/dev/null 2>&1 && return 0 ;;
        curl) curl --help >/dev/null 2>&1 && return 0 ;;
        busybox) busybox >/dev/null 2>&1 && return 0 ;;
        *) "$tool" --help >/dev/null 2>&1 && return 0 ;;
    esac
    return 1
}

# Получить путь к busybox или утилите
find_tool() {
    local tool="$1"
    type "$tool" 2>/dev/null | head -1 | awk '{print $NF}'
    return 0
}

# Определяем доступные HTTP-утилиты
detect_http_tools() {
    HTTP_TOOLS=""
    
    # curl — проверяем напрямую
    if curl --help >/dev/null 2>&1; then
        HTTP_TOOLS="$HTTP_TOOLS curl"
    fi
    # wget
    if wget --help >/dev/null 2>&1; then
        HTTP_TOOLS="$HTTP_TOOLS wget"
    fi
    # busybox wget (даже если wget недоступен отдельно)
    if busybox wget --help >/dev/null 2>&1; then
        HTTP_TOOLS="$HTTP_TOOLS busybox_wget"
    fi
    # python
    if python --version >/dev/null 2>&1 || python2 --version >/dev/null 2>&1; then
        HTTP_TOOLS="$HTTP_TOOLS python"
    fi
    
    echo "$HTTP_TOOLS"
}

# ----------------------------------------------------------------------------
# FETCH_URL — Универсальный загрузчик (Padavan BusyBox-friendly)
# ----------------------------------------------------------------------------
# Проблема: BusyBox wget не поддерживает:
#   -q (quiet)
#   -T / --timeout
#   -O (GNU wget да, BusyBox wget да, но разный синтаксис)
#   --tries
# BusyBox curl не поддерживает:
#   -f (fail)
#   --connect-timeout
#   --max-time
# Решение: пробуем все варианты, останавливаемся на первом успешном
# ----------------------------------------------------------------------------
fetch_url() {
    local url="$1" out="$2" max="${3:-90}"
    [ -z "$url" ] && return 1
    [ -z "$out" ] && return 1
    
    local rc=1
    
    # === Способ 1: GNU wget (полная версия) ===
    if [ "$rc" -ne 0 ] && wget --version 2>&1 | grep -q "GNU Wget"; then
        # GNU wget: поддерживает -q, --timeout, -O
        wget -q --timeout="$max" --tries=2 -O "$out" "$url" 2>/dev/null
        if [ $? -eq 0 ] && [ -s "$out" ]; then
            return 0
        fi
        rm -f "$out" 2>/dev/null
    fi
    
    # === Способ 2: BusyBox wget (минимальный) ===
    if [ "$rc" -ne 0 ] && wget --help 2>&1 | grep -q "BusyBox"; then
        # BusyBox wget: только -O URL
        # Нет таймаута, нет ретраев, нет -q
        # Пробуем просто скачать
        wget -O "$out" "$url" 2>/dev/null
        if [ $? -eq 0 ] && [ -s "$out" ]; then
            return 0
        fi
        rm -f "$out" 2>/dev/null
        
        # Иногда BusyBox wget требует --no-check-certificate для HTTPS
        wget --no-check-certificate -O "$out" "$url" 2>/dev/null
        if [ $? -eq 0 ] && [ -s "$out" ]; then
            return 0
        fi
        rm -f "$out" 2>/dev/null
    fi
    
    # === Способ 3: BusyBox wget через busybox напрямую ===
    if [ "$rc" -ne 0 ] && busybox --list 2>/dev/null | grep -q " wget"; then
        busybox wget -O "$out" "$url" 2>/dev/null
        if [ $? -eq 0 ] && [ -s "$out" ]; then
            return 0
        fi
        rm -f "$out" 2>/dev/null
    fi
    
    # === Способ 4: curl (любой версии) ===
    if [ "$rc" -ne 0 ] && curl --help >/dev/null 2>&1; then
        # Определяем: GNU curl или BusyBox curl
        if curl --version 2>&1 | grep -q "curl"; then
            # GNU curl: -f, -L, -k, -m, -s, -o
            curl -k -L -f -s -m "$max" --connect-timeout 30 -o "$out" "$url" 2>/dev/null
            if [ $? -eq 0 ] && [ -s "$out" ]; then
                return 0
            fi
            rm -f "$out" 2>/dev/null
        else
            # BusyBox curl: -k, -L, -o (но НЕ -f!)
            curl -k -L -o "$out" "$url" 2>/dev/null
            if [ $? -eq 0 ] && [ -s "$out" ]; then
                return 0
            fi
            rm -f "$out" 2>/dev/null
            
            # BusyBox curl может требовать --no-check-certificate
            curl --no-check-certificate -L -o "$out" "$url" 2>/dev/null
            if [ $? -eq 0 ] && [ -s "$out" ]; then
                return 0
            fi
            rm -f "$out" 2>/dev/null
        fi
    fi
    
    # === Способ 5: Python (если есть) ===
    if [ "$rc" -ne 0 ]; then
        if python -c "import sys" >/dev/null 2>&1; then
            python -c "
import urllib2, ssl
ctx = ssl.create_default_context()
ctx.check_hostname = False
ctx.verify_mode = ssl.CERT_NONE
try:
    r = urllib2.urlopen('$url', timeout=$max, context=ctx)
    with open('$out', 'wb') as f:
        f.write(r.read())
except Exception as e:
    sys.exit(1)
" 2>/dev/null
            if [ $? -eq 0 ] && [ -s "$out" ]; then
                return 0
            fi
            rm -f "$out" 2>/dev/null
        fi
    fi
    
    return 1
}

# ----------------------------------------------------------------------------
# ENDIAN DETECTION
# ----------------------------------------------------------------------------
detect_endian() {
    local endian="unknown"
    
    if command -v lscpu >/dev/null 2>&1; then
        local o
        o=$(lscpu 2>/dev/null | grep -i "byte order" | awk '{print tolower($NF)}' | tr -d ' \t\n')
        case "$o" in
            little) echo "le"; return ;;
            big)    echo "be"; return ;;
        esac
    fi
    
    if command -v getconf >/dev/null 2>&1; then
        local bo
        bo=$(getconf BYTE_ORDER 2>/dev/null | tr -d ' \t\n')
        case "$bo" in
            *LITTLE*|*1234*) echo "le"; return ;;
            *BIG*|*4321*)    echo "be"; return ;;
        esac
    fi
    
    if [ -r /proc/cpuinfo ]; then
        if grep -qiE "little.endian|\(LE\)" /proc/cpuinfo 2>/dev/null; then
            echo "le"; return
        fi
        if grep -qiE "big.endian|\(BE\)" /proc/cpuinfo 2>/dev/null; then
            echo "be"; return
        fi
        
        local soc
        soc=$(grep -m1 "system type" /proc/cpuinfo 2>/dev/null | sed -E 's/.*:\s*//')
        case "$soc" in
            *MT7621*|*MT7620*|*MT7628*|*MT7688*|*RT3052*|*RT3883*|*RT5350*|\
            *AR7240*|*AR7241*|*AR7242*|*AR9331*|*AR9341*|*AR9342*|*AR9344*|\
            *QCA9531*|*QCA9557*|*QCA9563*|*IPQ40xx*|*IPQ60xx*|*IPQ80xx*|\
            *MediaTek*|*Ralink*|*Atheros*)
                warn "SoC '$soc' → little-endian"
                echo "le"; return
                ;;
            *BCM63xx*|*BCM33xx*|*IXP4xx*|*Au1xxx*|*Loongson*|*Cavium*|*Octeon*|*CN38xx*|*CN56xx*|*CN63xx*)
                warn "SoC '$soc' → big-endian"
                echo "be"; return
                ;;
        esac
    fi
    
    # printf-тест
    local tf="/tmp/.endian_$$_$RANDOM"
    if printf '\x12\x34' > "$tf" 2>/dev/null; then
        local fb
        fb=$(od -An -tx1 "$tf" 2>/dev/null | awk '{print $1}' | tr -d ' \t\n')
        rm -f "$tf"
        case "$fb" in
            12) echo "be"; return ;;
            34) echo "le"; return ;;
        esac
    fi
    
    echo "unknown"
}

# ----------------------------------------------------------------------------
# ARCH DETECTION
# ----------------------------------------------------------------------------
detect_arch_raw() {
    local arch=""
    
    if [ -f /etc/os-release ]; then
        arch=$(grep -E "^OPENWRT_ARCH=" /etc/os-release 2>/dev/null \
            | head -1 | cut -d= -f2 | tr -d '"')
        [ -n "$arch" ] && { echo "openwrt:$arch"; return; }
    fi
    
    if [ -z "$arch" ] && command -v opkg >/dev/null 2>&1; then
        arch=$(opkg print-architecture 2>/dev/null \
            | sort -k3 -nr \
            | awk '$2 != "all" && $2 != "noarch" {print $2; exit}')
    fi
    
    [ -z "$arch" ] && arch=$(uname -m 2>/dev/null)
    
    if [ -z "$arch" ] || [ "$arch" = "unknown" ]; then
        if [ -r /proc/cpuinfo ]; then
            arch=$(grep -m1 -E "^(Hardware|machine|system type|cpu model)" \
                /proc/cpuinfo 2>/dev/null | sed -E 's/.*:\s*//')
        fi
    fi
    
    echo "$arch"
}

detect_arch_base() {
    local arch_raw="$1" endian="$2" base=""
    
    case "$arch_raw" in
        openwrt:*)
            local ow="${arch_raw#openwrt:}"
            case "$ow" in
                aarch64_*)    base="aarch64" ;;
                arm_*)        base="armv7" ;;
                i386_*)       base="i386" ;;
                mipsel_*)     base="mipsel" ;;
                mips_*)       base="mips" ;;
                mips64el_*)   base="mips64el" ;;
                mips64_*)     base="mips64" ;;
                loongarch64_*) base="loongarch64" ;;
                riscv64_*)    base="riscv64" ;;
                x86_64*)      base="x86_64" ;;
                *)            base="unknown" ;;
            esac
            ;;
        aarch64|*arm64*)       base="aarch64" ;;
        armv6*|*arm1176*|*arm926*) base="armv6" ;;
        armv7*|*cortex-a5*|*cortex-a7*|*cortex-a9*|*cortex-a15*) base="armv7" ;;
        arm*)                  base="armv7" ;;
        mipsel|mipsle)         base="mipsel" ;;
        mips)
            if [ "$endian" = "le" ]; then
                warn "uname=mips, но endianness=le → mipsel"
                base="mipsel"
            elif [ "$endian" = "be" ]; then
                base="mips"
            else
                # Не гадаем: LE и BE несовместимы на уровне набора команд —
                # запуск не того варианта либо не запустится, либо (реже)
                # приведёт к некорректному поведению. Явная остановка
                # безопаснее слепого выбора дефолта.
                base="undetermined"
            fi
            ;;
        mips64el|mips64le)     base="mips64el" ;;
        mips64*)
            [ "$endian" = "le" ] && base="mips64el" || base="mips64"
            ;;
        riscv64*)              base="riscv64" ;;
        loongarch64|loong64|loong*) base="loongarch64" ;;
        s390x*)                base="s390x" ;;
        i?86|i386)             base="i386" ;;
        x86_64|amd64)          base="x86_64" ;;
        *)                     base="unknown" ;;
    esac
    
    echo "$base"
}

# ----------------------------------------------------------------------------
# LIBC DETECTION
# ----------------------------------------------------------------------------
detect_libc() {
    local p
    for p in /lib /usr/lib /lib64 /usr/lib64 /opt/lib /opt/usr/lib; do
        [ -d "$p" ] || continue
        if ls "$p"/ld-musl-*   >/dev/null 2>&1; then echo "musl"; return; fi
        if ls "$p"/ld-uClibc-* >/dev/null 2>&1; then echo "uclibc"; return; fi
        if ls "$p"/ld-linux-*  >/dev/null 2>&1; then echo "glibc"; return; fi
    done
    
    [ -f /lib/libc.musl-* ]    && { echo "musl"; return; }
    [ -f /lib/libc.so.6 ]      && { echo "glibc"; return; }
    [ -f /usr/lib/libc.so.6 ]  && { echo "glibc"; return; }
    [ -f /lib/libuClibc-* ]    && { echo "uclibc"; return; }
    [ -f /lib/libc.so.0 ]      && { echo "uclibc"; return; }
    [ -f /lib/ld-uClibc.so.0 ] && { echo "uclibc"; return; }
    
    if command -v ldd >/dev/null 2>&1; then
        local v
        v=$(ldd --version 2>&1 | head -1)
        echo "$v" | grep -qi musl   && { echo "musl"; return; }
        echo "$v" | grep -qi uClibc && { echo "uclibc"; return; }
        echo "$v" | grep -qi glibc  && { echo "glibc"; return; }
    fi
    
    if [ -f /proc/sys/kernel/osrelease ]; then
        grep -qiE "hnd|bcm4908" /proc/sys/kernel/osrelease 2>/dev/null \
            && { echo "uclibc"; return; }
    fi
    
    echo "unknown"
}

# ----------------------------------------------------------------------------
# FIRMWARE
# ----------------------------------------------------------------------------
detect_firmware() {
    if [ -f /etc/openwrt_release ] || [ -f /etc/openwrt_version ]; then
        echo "openwrt"
    elif [ -f /etc/padavan.conf ] || [ -d "/opt/home/admin" ] || [ -f /etc/storage ]; then
        echo "padavan"
    elif [ -f /etc/asusfw.conf ] || [ -d "/jffs/scripts" ]; then
        echo "merlin"
    elif [ -f /etc/keenetic/release.conf ] || [ -d "/opt/etc/ndm" ]; then
        echo "keenetic"
    elif [ -f /etc/entware_release ]; then
        echo "entware"
    else
        echo "unknown"
    fi
}

# ----------------------------------------------------------------------------
# SUB-ARCH
# ----------------------------------------------------------------------------
get_cpu_subarch() {
    local m=""
    [ -r /proc/cpuinfo ] && \
        m=$(grep -m1 -E "model name|Processor|Hardware|system type" /proc/cpuinfo 2>/dev/null \
            | sed -E 's/.*:\s*//')
    [ -z "$m" ] && [ -f /etc/board.json ] && \
        m=$(grep -o '"model":"[^"]*"' /etc/board.json 2>/dev/null | head -1 | cut -d'"' -f4)
    echo "$m"
}

# ----------------------------------------------------------------------------
# CANDIDATES
# ----------------------------------------------------------------------------
build_candidates() {
    local arch_base="$1" libc="$2" candidates=""
    
    case "$arch_base" in
        aarch64)
            case "$libc" in
                musl)  candidates="linux-arm64-musl linux-arm64 linux-arm64-glibc" ;;
                glibc) candidates="linux-arm64-glibc linux-arm64 linux-arm64-musl" ;;
                *)     candidates="linux-arm64 linux-arm64-musl linux-arm64-glibc" ;;
            esac
            candidates="$candidates linux-arm64-purego"
            ;;
        armv7)
            case "$libc" in
                musl)  candidates="linux-armv7-musl linux-armv7 linux-armv7-glibc" ;;
                glibc) candidates="linux-armv7-glibc linux-armv7 linux-armv7-musl" ;;
                *)     candidates="linux-armv7 linux-armv7-musl linux-armv7-glibc" ;;
            esac
            ;;
        armv6)    candidates="linux-armv6" ;;
        mipsel)   candidates="linux-mipsle linux-mipsle-softfloat" ;;
        mips)     candidates="linux-mips linux-mips-softfloat" ;;
        mips64el) candidates="linux-mips64le" ;;
        mips64)   candidates="linux-mips64" ;;
        riscv64)
            case "$libc" in
                musl)  candidates="linux-riscv64-musl linux-riscv64 linux-riscv64-glibc" ;;
                glibc) candidates="linux-riscv64-glibc linux-riscv64 linux-riscv64-musl" ;;
                *)     candidates="linux-riscv64 linux-riscv64-musl linux-riscv64-glibc" ;;
            esac
            ;;
        loongarch64) candidates="linux-loong64-glibc linux-loong64-musl" ;;
        s390x)       candidates="linux-s390x" ;;
        i386|x86_64)
            err "x86/x86_64 исключены"
            return 1
            ;;
        *)
            err "Неизвестная архитектура: $arch_base"
            return 1
            ;;
    esac
    
    echo "$candidates"
    return 0
}

# ----------------------------------------------------------------------------
# ROLLBACK
# ----------------------------------------------------------------------------
rollback() {
    log ""
    err "CRITICAL: Installation failed! Rollback..."
    if [ "$BACKUP_PERFORMED" = "1" ] && [ -n "$BACKUP_DIR" ] && [ -d "$BACKUP_DIR" ]; then
        info "Восстанавливаю бэкап: $BACKUP_DIR → $WORKDIR"
        rm -rf "$WORKDIR" 2>/dev/null
        mv "$BACKUP_DIR" "$WORKDIR" 2>/dev/null \
            && ok "Бэкап восстановлен" \
            || warn "Ручное восстановление: $BACKUP_DIR"
    elif [ -n "$WORKDIR" ] && [ -d "$WORKDIR" ]; then
        cd /tmp 2>/dev/null || cd /
        rm -rf "$WORKDIR" 2>/dev/null
    fi
    err "Установка прервана."
    exit 1
}

# ----------------------------------------------------------------------------
# ABORT: endianness не определён — не гадаем, не качаем, чистим хвосты
# ----------------------------------------------------------------------------
abort_unknown_endian() {
    log ""
    err "================================================================"
    err "  Endianness процессора определить не удалось"
    err "================================================================"
    err "uname -m вернул 'mips' без явного признака LE/BE, а lscpu, getconf,"
    err "/proc/cpuinfo и printf-тест байтов не дали однозначного ответа."
    err ""
    err "LE и BE бинарники несовместимы на уровне набора инструкций — запуск"
    err "не того варианта завершится ошибкой или некорректным поведением."
    err "Установка прервана ДО скачивания каких-либо файлов."
    err ""
    err "Укажите архитектуру вручную и перезапустите:"
    err "  FORCE_ENDIAN=le $0   # почти все Padavan-роутеры: MT7620/MT7621/RT3052"
    err "  FORCE_ENDIAN=be $0   # редкие big-endian MIPS-платформы"
    err ""

    # Подчищаем незавершённые staging-каталоги ОТ ПРЕДЫДУЩИХ прерванных
    # попыток (например, если предыдущий запуск убили Ctrl+C после скачивания).
    if [ -n "$INSTALL_ROOT" ]; then
        for stale in "${INSTALL_ROOT}"/.staging_*; do
            [ -d "$stale" ] || continue
            warn "Удаляю незавершённый каталог предыдущей попытки: $stale"
            rm -rf "$stale" 2>/dev/null
        done
    fi

    exit 1
}

# ============================================================================
# MAIN
# ============================================================================
log "${CYAN}================================================================${RESET}"
log "${CYAN}  Cross-Protocol Breeder — Smart Installer v3.4                ${RESET}"
log "${CYAN}================================================================${RESET}"

# === [1/8] Storage =========================================================
log ""
log "${YELLOW}[1/8] Storage & free space${RESET}"

for p in /opt /mnt /tmp; do
    if [ -d "$p" ]; then
        fk=$(get_free_kb "$p")
        info "$p: ${fk:-?} KB свободно"
    fi
done

INSTALL_ROOT=""
USE_COMPRESSED=0
for entry in "/opt/tmp_sb_ext|//opt" "/mnt/tmp_sb_ext|/mnt" "/tmp_sb_ext|/tmp"; do
    target=$(echo "$entry" | cut -d'|' -f1)
    parent=$(echo "$entry" | cut -d'|' -f2)
    [ -d "$parent" ] || mkdir -p "$parent" 2>/dev/null
    [ -d "$parent" ] || continue
    if ! touch "$parent/.twr" 2>/dev/null; then
        warn "$parent: read-only"
        continue
    fi
    rm -f "$parent/.twr"
    fk=$(get_free_kb "$parent")
    [ -z "$fk" ] && continue
    if [ "$fk" -ge 81920 ] 2>/dev/null; then
        INSTALL_ROOT="$target"; USE_COMPRESSED=0; break
    elif [ "$fk" -ge 25600 ] 2>/dev/null; then
        INSTALL_ROOT="$target"; USE_COMPRESSED=1; break
    else
        warn "$parent: $fk KB (нужно ≥25 MB)"
    fi
done

if [ -z "$INSTALL_ROOT" ]; then
    err "Ни один путь не имеет свободного места!"
    exit 1
fi
ok "Путь: $INSTALL_ROOT (свободно: $(get_free_kb "$(dirname "$INSTALL_ROOT")") KB)"

# === [2/8] Detect system ===================================================
log ""
log "${YELLOW}[2/8] Detecting system${RESET}"

FW=$(detect_firmware)
ok "Firmware:    ${CYAN}${FW}${RESET}"

ENDIAN=$(detect_endian)
ok "Endianness:  ${CYAN}${ENDIAN}${RESET}"

ARCH_RAW=$(detect_arch_raw)
ok "uname -m:    ${CYAN}${ARCH_RAW}${RESET}"

LIBC=$(detect_libc)
ok "libc:        ${CYAN}${LIBC}${RESET}"

SUBARCH=$(get_cpu_subarch)
[ -n "$SUBARCH" ] && ok "CPU/Model:   ${CYAN}${SUBARCH}${RESET}"

[ -n "${FORCE_ENDIAN:-}" ] && {
    warn "FORCE_ENDIAN=$FORCE_ENDIAN (override)"
    ENDIAN="$FORCE_ENDIAN"
}

ARCH_BASE=$(detect_arch_base "$ARCH_RAW" "$ENDIAN")
case "$ARCH_BASE" in
    i386|x86_64)
        err "x86 исключены"
        exit 1
        ;;
    undetermined)
        abort_unknown_endian
        ;;
    unknown)
        err "Не удалось определить архитектуру"
        exit 1
        ;;
esac
ok "Base arch:   ${CYAN}${ARCH_BASE}${RESET}"

# === [3/8] Candidates ======================================================
log ""
log "${YELLOW}[3/8] Building candidates${RESET}"

WORKDIR="${INSTALL_ROOT}/.staging_$$"
mkdir -p "$WORKDIR" || { err "Cannot create $WORKDIR"; exit 1; }
cd "$WORKDIR" || exit 1

CANDIDATES=$(build_candidates "$ARCH_BASE" "$LIBC")
if [ $? -ne 0 ]; then
    rm -rf "$WORKDIR"
    exit 1
fi

info "Кандидаты (по приоритету):"
for c in $CANDIDATES; do dbg "$c"; done

# === [4/8] HTTP tools & deps (Padavan-friendly) ============================
log ""
log "${YELLOW}[4/8] Checking HTTP tools${RESET}"

HTTP_TOOLS=$(detect_http_tools)
if [ -z "$HTTP_TOOLS" ]; then
    err "Не найдено ни одной HTTP-утилиты!"
    err "Установите wget или curl:"
    err "  - На OpenWrt: opkg install wget curl"
    err "  - На Padavan: обычно wget уже есть"
    err ""
    err "Проверьте вручную:"
    err "  ls -la /bin/wget /bin/curl /bin/busybox"
    rollback
fi

info "Доступные HTTP-утилиты:${CYAN}${HTTP_TOOLS}${RESET}"

# === [5/8] Download & verify ==============================================
log ""
log "${YELLOW}[5/8] Downloading binary${RESET}"

INSTALLED=0
SELECTED_FILE=""
DOWNLOAD_TOOL_USED=""

for cand in $CANDIDATES; do
    fname="sing-box-${SB_VERSION}-${cand}.tar.gz"
    dest="${WORKDIR}/${fname}"
    
    info "Пробую: ${CYAN}${cand}${RESET}"
    
    # Пробуем скачать через доступные утилиты
    DOWNLOADED=0
    
    # Способ 1: GNU wget
    if [ "$DOWNLOADED" -eq 0 ] && wget --version 2>&1 | grep -q "GNU Wget"; then
        if wget -q --timeout=120 --tries=2 -O "$dest" "${BINARY_BASE}/${fname}" 2>/dev/null; then
            [ -s "$dest" ] && DOWNLOADED=1 && DOWNLOAD_TOOL_USED="wget (GNU)"
        fi
        [ "$DOWNLOADED" -eq 0 ] && rm -f "$dest"
    fi
    
    # Способ 2: BusyBox wget
    if [ "$DOWNLOADED" -eq 0 ] && wget --help 2>&1 | grep -q "BusyBox"; then
        # BusyBox wget — минимум опций
        if wget --no-check-certificate -O "$dest" "${BINARY_BASE}/${fname}" 2>/dev/null; then
            [ -s "$dest" ] && DOWNLOADED=1 && DOWNLOAD_TOOL_USED="wget (BusyBox)"
        fi
        [ "$DOWNLOADED" -eq 0 ] && rm -f "$dest"
    fi
    
    # Способ 3: curl (GNU)
    if [ "$DOWNLOADED" -eq 0 ] && curl --version 2>&1 | grep -q "curl"; then
        if curl -k -L -f -s -m 120 --connect-timeout 30 \
                -o "$dest" "${BINARY_BASE}/${fname}" 2>/dev/null; then
            [ -s "$dest" ] && DOWNLOADED=1 && DOWNLOAD_TOOL_USED="curl (GNU)"
        fi
        [ "$DOWNLOADED" -eq 0 ] && rm -f "$dest"
    fi
    
    # Способ 4: curl (BusyBox) — без -f!
    if [ "$DOWNLOADED" -eq 0 ] && curl --help >/dev/null 2>&1; then
        if curl -k -L --no-check-certificate -o "$dest" \
                "${BINARY_BASE}/${fname}" 2>/dev/null; then
            [ -s "$dest" ] && DOWNLOADED=1 && DOWNLOAD_TOOL_USED="curl (BusyBox)"
        fi
        [ "$DOWNLOADED" -eq 0 ] && rm -f "$dest"
    fi
    
    if [ "$DOWNLOADED" -eq 0 ]; then
        warn "$fname: не удалось скачать"
        continue
    fi
    
    ok "Скачано ($DOWNLOAD_TOOL_USED): $(get_file_size_kb "$dest") KB"
    
    # Валидация gzip
    if ! gzip -t "$dest" >/dev/null 2>&1; then
        warn "$fname: невалидный gzip"
        rm -f "$dest"
        continue
    fi
    
    ok "gzip-валидация пройдена"
    SELECTED_FILE="$dest"
    SELECTED_PKG_TYPE="targz"
    INSTALLED=1
    break
done

if [ "$INSTALLED" -ne 1 ] || [ -z "$SELECTED_FILE" ]; then
    err "Не удалось скачать ни один из кандидатов!"
    err ""
    err "Возможные причины:"
    err "  1) Нет доступа к ${BINARY_BASE}/"
    err "  2) Файл отсутствует в репозитории"
    err ""
    err "Проверьте вручную:"
    err "  wget --no-check-certificate -O /tmp/test.tar.gz \\"
    err "    ${BINARY_BASE}/sing-box-${SB_VERSION}-${CANDIDATES%% *}.tar.gz"
    rollback
fi

# === [6/8] Extract & test ==================================================
log ""
log "${YELLOW}[6/8] Extracting & testing${RESET}"

if ! tar -xzf "$SELECTED_FILE" 2>/dev/null; then
    err "Ошибка распаковки"
    rollback
fi

ext_dir=$(find . -mindepth 1 -maxdepth 1 -type d 2>/dev/null | head -1)
if [ -z "$ext_dir" ] || [ ! -f "$ext_dir/sing-box" ]; then
    err "Бинарник sing-box не найден в архиве"
    ls -la
    rollback
fi

mv "$ext_dir/sing-box" "$WORKDIR/sing-box" || rollback
chmod +x "$WORKDIR/sing-box"
rm -rf "$ext_dir" "$SELECTED_FILE"
ok "Распаковано: $WORKDIR/sing-box"

SB_OUT=$("$WORKDIR/sing-box" version 2>&1)
SB_RC=$?
if [ $SB_RC -ne 0 ]; then
    err "Бинарник не запускается!"
    err "Вывод: $SB_OUT"
    err ""
    err "Возможные причины:"
    err "  1) Неправильная архитектура (выбрана $ARCH_BASE, но реально другая)"
    err "  2) Попробуйте: FORCE_ENDIAN=le $0  (для MT7620/MT7621)"
    rollback
fi
ok "Бинарник работает: $(echo "$SB_OUT" | head -1)"

# === [7/8] Finalize directory ==============================================
log ""
log "${YELLOW}[7/8] Finalizing directory${RESET}"

FINAL_DIR="${INSTALL_ROOT}/sing-box-${SB_VERSION}"
if [ -d "$FINAL_DIR" ]; then
    BACKUP_DIR="${FINAL_DIR}_backup_$(date +%Y%m%d_%H%M%S)"
    warn "Существующая установка → бэкап: $BACKUP_DIR"
    mv "$FINAL_DIR" "$BACKUP_DIR" && BACKUP_PERFORMED=1
fi

mkdir -p "$FINAL_DIR" || rollback
cp "$WORKDIR/sing-box" "$FINAL_DIR/"
rm -rf "$WORKDIR"
WORKDIR="$FINAL_DIR"
cd "$WORKDIR" || rollback
ok "Установлено в: $WORKDIR"

# Скачиваем скрипты (через тот же fetch_url)
for f in update_hybrid.sh converter.lua conf3_final.json gen_links.sh; do
    info "Загрузка $f..."
    if fetch_url "$REPO_RAW/$f" "$f" 60; then
        ok "$f"
    else
        err "Не удалось скачать $f"
        rollback
    fi
done
chmod +x update_hybrid.sh gen_links.sh

# Сертификаты
CERT_DIR="$WORKDIR/certs/grpc"
mkdir -p "$CERT_DIR"
if command -v openssl >/dev/null 2>&1; then
    openssl ecparam -genkey -name prime256v1 -out "$CERT_DIR/h2.pem" 2>/dev/null
    openssl req -new -x509 -days 36500 -key "$CERT_DIR/h2.pem" \
        -out "$CERT_DIR/h2.cert" -subj "/CN=cloudflare.com" 2>/dev/null
    SS_PASS=$(openssl rand -hex 12)
    HY2_PASS=$(openssl rand -hex 10)
else
    SS_PASS=$(tr -dc 'a-f0-9' </dev/urandom 2>/dev/null | head -c 24)
    HY2_PASS=$(tr -dc 'a-f0-9' </dev/urandom 2>/dev/null | head -c 20)
fi
if command -v jq >/dev/null 2>&1; then
    jq --arg sp "$SS_PASS" --arg hp "$HY2_PASS" '
        (.inbounds[]? | select(.tag == "ss-in")  | .password) = $sp |
        (.inbounds[]? | select(.tag == "hy2-in") | .users[0].password) = $hp
    ' conf3_final.json > tmp.json && mv tmp.json conf3_final.json
fi
ok "Сертификаты и пароли готовы"

# === [8/8] Autostart & cron ================================================
log ""
log "${YELLOW}[8/8] Configuring autostart & cron${RESET}"

RUN_BIN="$WORKDIR/sing-box"
STARTED="/etc/storage/started_script.sh"
CRON_F="/etc/storage/cron/crontabs/admin"
RUN_CMD="nohup $RUN_BIN run -c $WORKDIR/conf_chain6.json >/dev/null 2>&1 &"
CRON_CMD="0 4 */3 * * $WORKDIR/update_hybrid.sh >/dev/null 2>&1"

if [ -f "$STARTED" ] && ! grep -q "sing-box" "$STARTED" 2>/dev/null; then
    {
        echo ""
        echo "# Sing-Box Cross-Protocol Breeder"
        echo "$RUN_CMD"
    } >> "$STARTED"
    ok "Добавлено в $STARTED"
elif [ ! -f "$STARTED" ]; then
    warn "$STARTED не найден"
    warn "Добавьте вручную: $RUN_CMD"
fi

if [ -d "/etc/storage/cron/crontabs" ]; then
    touch "$CRON_F" 2>/dev/null
    if ! grep -q "update_hybrid.sh" "$CRON_F" 2>/dev/null; then
        echo "$CRON_CMD" >> "$CRON_F"
        killall crond 2>/dev/null; crond 2>/dev/null
        ok "Cron настроен"
    fi
fi

command -v mtd_storage.sh >/dev/null 2>&1 && mtd_storage.sh save >/dev/null 2>&1

# === ИТОГ ==================================================================
log ""
log "${CYAN}================================================================${RESET}"
log "${GREEN}  ✅ Installation Successfully Completed!${RESET}"
log "${CYAN}================================================================${RESET}"
log "Firmware:     ${YELLOW}${FW}${RESET}"
log "uname -m:     ${YELLOW}${ARCH_RAW}${RESET}"
log "Endianness:   ${YELLOW}${ENDIAN}${RESET}"
log "Архитектура:  ${YELLOW}${ARCH_BASE}${RESET}"
log "libc:         ${YELLOW}${LIBC}${RESET}"
[ -n "$SUBARCH" ] && log "CPU/Model:    ${YELLOW}${SUBARCH}${RESET}"
log "Бинарник:     ${YELLOW}$RUN_BIN${RESET}"
log "Размер:       ${YELLOW}$(get_file_size_kb "$RUN_BIN") KB${RESET}"
log "Каталог:      ${YELLOW}$WORKDIR${RESET}"
log ""
log "Запустите: ${GREEN}./update_hybrid.sh${RESET}"
log ""

./gen_links.sh 2>/dev/null
sleep 2
./update_hybrid.sh
