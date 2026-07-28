#!/bin/sh
# =====================================================================
# gen_links.sh (Cross-Protocol Breeder Edition)
# =====================================================================

WORKDIR="/opt/sb-breeder"
CONF="$WORKDIR/conf_chain6.json"
OUT_FILE="$WORKDIR/clients.txt"

# ЦВЕТА
GREEN='\033[1;32m'
RED='\033[1;31m'
YELLOW='\033[1;33m'
CYAN='\033[1;36m'
BLUE='\033[1;34m'
RESET='\033[0m'

echo -e "${CYAN}================================================================${RESET}"
echo -e "${CYAN}  Cross-Protocol Breeder - Client Link Generator                ${RESET}"
echo -e "${CYAN}================================================================${RESET}"

if [ ! -f "$CONF" ]; then
    echo -e "${RED}ERROR: Target config $CONF not found!${RESET}"
    echo -e "${YELLOW}Please run update_hybrid.sh first to build the multi-hop chains.${RESET}"
    exit 1
fi

# 1. Автоматическое определение локального IP адреса роутера
SERVER_IP=$(nvram get lan_ipaddr 2>/dev/null)
if [ -z "$SERVER_IP" ]; then
    # Фолбэк 1: Чтение IP адреса с сетевого интерфейса локальной сети (br0)
    SERVER_IP=$(ip addr show br0 2>/dev/null | grep -w inet | awk '{print $2}' | cut -d/ -f1)
fi
if [ -z "$SERVER_IP" ]; then
    # Фолбэк 2: Если команды не сработали, ставим классический дефолт
    SERVER_IP="192.168.1.1" 
fi

echo -e "${GREEN}➔ Detected Router LAN IP:${RESET} $SERVER_IP"
echo -e "➔ Generating links... → $OUT_FILE\n"
> "$OUT_FILE"

b64enc() {
    echo -n "$1" | openssl base64 -A 2>/dev/null | tr -d '\n\r'
}

# --- 1. Mixed и HTTP ---
if jq -e '.inbounds[] | select(.type=="mixed" or .type=="http")' "$CONF" >/dev/null 2>&1; then
    echo -e "${BLUE}--- HTTP / Mixed Proxy ---${RESET}"
    jq -c '.inbounds[] | select(.type=="mixed" or .type=="http")' "$CONF" | while read -r line; do
        TAG=$(echo "$line" | jq -r '.tag')
        PORT=$(echo "$line" | jq -r '.listen_port')
        LINK="http://$SERVER_IP:$PORT#$TAG"
        echo "$LINK" | tee -a "$OUT_FILE"
    done
    echo ""
fi

# --- 2. SOCKS5 ---
# Игнорируем socks-test, так как это внутренний порт для curl во время сканирования
if jq -e '.inbounds[] | select(.type=="socks" and .tag!="socks-test")' "$CONF" >/dev/null 2>&1; then
    echo -e "${BLUE}--- SOCKS5 ---${RESET}"
    jq -c '.inbounds[] | select(.type=="socks" and .tag!="socks-test")' "$CONF" | while read -r line; do
        TAG=$(echo "$line" | jq -r '.tag')
        PORT=$(echo "$line" | jq -r '.listen_port')
        LINK="socks5://$SERVER_IP:$PORT#$TAG"
        echo "$LINK" | tee -a "$OUT_FILE"
    done
    echo ""
fi

# --- 3. Shadowsocks ---
if jq -e '.inbounds[] | select(.type=="shadowsocks")' "$CONF" >/dev/null 2>&1; then
    echo -e "${BLUE}--- Shadowsocks ---${RESET}"
    jq -c '.inbounds[] | select(.type=="shadowsocks")' "$CONF" | while read -r line; do
        TAG=$(echo "$line" | jq -r '.tag')
        PORT=$(echo "$line" | jq -r '.listen_port')
        METHOD=$(echo "$line" | jq -r '.method')
        PASS=$(echo "$line" | jq -r '.password')
        AUTH=$(b64enc "$METHOD:$PASS")
        LINK="ss://$AUTH@$SERVER_IP:$PORT#$TAG"
        echo "$LINK" | tee -a "$OUT_FILE"
    done
    echo ""
fi

# --- 4. Hysteria 2 ---
if jq -e '.inbounds[] | select(.type=="hysteria2")' "$CONF" >/dev/null 2>&1; then
    echo -e "${BLUE}--- Hysteria 2 ---${RESET}"
    jq -c '.inbounds[] | select(.type=="hysteria2")' "$CONF" | while read -r line; do
        TAG=$(echo "$line" | jq -r '.tag')
        PORT=$(echo "$line" | jq -r '.listen_port')
        PASS=$(echo "$line" | jq -r '.users[0].password // .password')
        LINK="hy2://$PASS@$SERVER_IP:$PORT?insecure=1#$TAG"
        echo "$LINK" | tee -a "$OUT_FILE"
    done
    echo ""
fi

# --- 5. VLESS (Если поднят как входящий) ---
if jq -e '.inbounds[] | select(.type=="vless")' "$CONF" >/dev/null 2>&1; then
    echo -e "${BLUE}--- VLESS ---${RESET}"
    jq -c '.inbounds[] | select(.type=="vless")' "$CONF" | while read -r line; do
        TAG=$(echo "$line" | jq -r '.tag')
        PORT=$(echo "$line" | jq -r '.listen_port')
        UUID=$(echo "$line" | jq -r '.users[0].uuid // .uuid')
        LINK="vless://$UUID@$SERVER_IP:$PORT?encryption=none&security=none&type=tcp#$TAG"
        echo "$LINK" | tee -a "$OUT_FILE"
    done
    echo ""
fi

# --- 6. Trojan (Если поднят как входящий) ---
if jq -e '.inbounds[] | select(.type=="trojan")' "$CONF" >/dev/null 2>&1; then
    echo -e "${BLUE}--- Trojan ---${RESET}"
    jq -c '.inbounds[] | select(.type=="trojan")' "$CONF" | while read -r line; do
        TAG=$(echo "$line" | jq -r '.tag')
        PORT=$(echo "$line" | jq -r '.listen_port')
        PASS=$(echo "$line" | jq -r '.users[0].password // .password')
        LINK="trojan://$PASS@$SERVER_IP:$PORT?security=none#$TAG"
        echo "$LINK" | tee -a "$OUT_FILE"
    done
    echo ""
fi

echo -e "${GREEN}DONE! All links saved to $OUT_FILE${RESET}"
