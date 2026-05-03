#!/bin/bash
# DuckDNS IP 自動更新腳本
# 同時更新 amee-bw 與 bw-internal 兩個子網域

TOKEN="f11b2dc3-f6bc-49db-b373-1ee80913e091"
LOGFILE="/var/log/duckdns-update.log"

update_domain() {
    local DOMAIN="$1"
    RESULT=$(curl -s "https://www.duckdns.org/update/${DOMAIN}/${TOKEN}/")
    TIMESTAMP=$(date '+%Y-%m-%d %H:%M:%S')
    echo "${TIMESTAMP} [${DOMAIN}] ${RESULT}" >> "$LOGFILE"
}

update_domain "amee-bw"
# update_domain "bw-internal" # 內網 ip 不需要動態更新
