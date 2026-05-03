#!/bin/bash
# duckdns-sync.sh
# 從 DuckDNS 權威 DNS 查詢真實 IP，並同步更新 dnsmasq 的本地覆蓋設定
# 若外網不通，則保留既有設定（不修改）

DNSMASQ_CONF="/etc/dnsmasq.d/bothwell.conf"
LOGFILE="/var/log/duckdns-sync.log"
TIMESTAMP=$(date '+%Y-%m-%d %H:%M:%S')

# 使用 Google Public DNS 8.8.8.8 查詢，確保是從外部取得真實 IP
query_ip() {
    dig +short "$1" @8.8.8.8 2>/dev/null | grep -E '^[0-9]+\.[0-9]+\.[0-9]+\.[0-9]+$' | head -1
}

AMEE_REAL_IP=$(query_ip "amee-bw.duckdns.org")
INTERNAL_REAL_IP=$(query_ip "bw-internal.duckdns.org")

# 外網不通時 dig 回傳空值，直接跳出保留舊設定
if [[ -z "$AMEE_REAL_IP" || -z "$INTERNAL_REAL_IP" ]]; then
    echo "${TIMESTAMP} [WARN] 無法從外部解析 DuckDNS，外網可能中斷，保留現有 dnsmasq 設定。" >> "$LOGFILE"
    exit 0
fi

echo "${TIMESTAMP} [INFO] amee-bw 真實 IP: ${AMEE_REAL_IP} / bw-internal 真實 IP: ${INTERNAL_REAL_IP}" >> "$LOGFILE"

# 更新 dnsmasq 設定中的 address 行
# amee-bw 在內網存取時固定指向本機 192.168.246.251（NAT hairpin 防呆）
# bw-internal 同步為 DuckDNS 上的真實 IP（應為 192.168.246.251，但自動跟隨）
CURRENT_INTERNAL=$(grep "address=/bw-internal.duckdns.org/" "$DNSMASQ_CONF" | grep -oE '[0-9]+\.[0-9]+\.[0-9]+\.[0-9]+')

if [[ "$CURRENT_INTERNAL" != "$INTERNAL_REAL_IP" ]]; then
    echo "${TIMESTAMP} [UPDATE] bw-internal IP 變更: ${CURRENT_INTERNAL} -> ${INTERNAL_REAL_IP}，更新 dnsmasq 設定。" >> "$LOGFILE"
    sed -i "s|address=/bw-internal.duckdns.org/.*|address=/bw-internal.duckdns.org/${INTERNAL_REAL_IP}|" "$DNSMASQ_CONF"
    # 同步更新 amee-bw 指向 (內網一律指向 Nginx 本機)
    sed -i "s|address=/amee-bw.duckdns.org/.*|address=/amee-bw.duckdns.org/${INTERNAL_REAL_IP}|" "$DNSMASQ_CONF"
    # 重新載入 dnsmasq
    systemctl reload dnsmasq
    echo "${TIMESTAMP} [OK] dnsmasq 已重新載入。" >> "$LOGFILE"
else
    echo "${TIMESTAMP} [OK] IP 無變更，無需更新。" >> "$LOGFILE"
fi
