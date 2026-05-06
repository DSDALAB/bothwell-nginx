# Bothwell Nginx Reverse Proxy 管理

這個專案使用 Git 來統一管理 Nginx 的反向代理 (Reverse Proxy) 設定與 TCP 轉發 (Stream) 設定。

## 目錄結構
- `conf.d/`: 存放 HTTP / HTTPS 反向代理設定 (會同步到 `/etc/nginx/conf.d/`)
  - `amee-bw.duckdns.org.conf`: 公網域名設定 (HTTP + HTTPS)
  - `bw-internal.duckdns.org.conf`: 內網域名設定 (HTTP + HTTPS)
  - `direct-ip.conf`: 純 IP 直連設定 (HTTP only)
  - `proxy-defaults.conf`: 全域代理預設參數（http 層級，對齊後端 Apache/PHP 設定）
- `stream.d/`: 存放 TCP / UDP 轉發設定 (會同步到 `/etc/nginx/stream.conf.d/`)
- `dnsmasq/bothwell.conf`: dnsmasq 本地 DNS 設定備份 (系統實際設定在 `/etc/dnsmasq.d/bothwell.conf`)
- `sync.sh`: 設定檔同步腳本，提供自動 Git Commit、複製到系統目錄、驗證並重新載入 Nginx 配置。
- `duckdns-update.sh`: DuckDNS 動態 IP 自動更新腳本，由 crontab 每 5 分鐘自動執行。
- `duckdns-sync.sh`: 從 DuckDNS 權威 DNS 同步真實 IP 到 dnsmasq 本地覆蓋設定。
- `AGENT.md`: 提供給 AI Agent 參考的專案維護指南與上下文。

## 服務與網路配置

### 主機資訊
- **Nginx 主機 eth0 (Proxmox 內網)**: `192.168.246.251`
- **Nginx 主機 eth1 (LAN)**: `10.1.0.102`
- **對外公網 IP**: `220.135.228.168`

### 內部網路架構
| 服務 | IP | 狀態 |
|---|---|---|
| Nginx 主機 | `10.1.0.102` / `192.168.246.251` | 運行中 |
| Windows XAMPP | `10.1.0.200:80 & 443` | 現役 |
| LXC XAMPP | `10.1.0.100:80 & 443` | 遷移目標 |
| FastAPI 服務 | `10.1.0.101:80` | 運行中 |
| Windows SQL Server | `10.1.0.200:1433` | 現役 |
| LXC SQL Server | `10.1.0.104:1433` | 遷移目標 |

### 域名與存取規則

#### `amee-bw.duckdns.org` (公網域名 → `220.135.228.168`)
- HTTP 與 HTTPS **皆可存取，不強制跳轉**
- HTTPS 憑證由 Let's Encrypt 簽發，自動續簽
- `/` → Windows XAMPP (`10.1.0.200:80`)
- `/test/` → LXC XAMPP (`10.1.0.100:80`)
- `/api/` → FastAPI (`10.1.0.101:80`)，路徑原樣傳遞
- `/api/docs` → FastAPI Swagger UI

#### `bw-internal.duckdns.org` (內網域名 → `192.168.246.251`)
- HTTP 與 HTTPS **皆可存取，不強制跳轉**
- HTTPS 憑證由 Let's Encrypt (DNS-01 DuckDNS 驗證) 簽發，自動續簽
- 代理規則與 `amee-bw.duckdns.org` **完全相同**
- 適合內網設備使用（流量不出外網）

#### 純 IP 直連 (`http://220.135.228.168`)
- 僅 HTTP，無 HTTPS (IP 無法申請公信 SSL 憑證)
- `/` → Windows XAMPP (`10.1.0.200:80`)
- `/test/` → LXC XAMPP (`10.1.0.100:80`)

### TCP 轉發 (SQL Server)
- 外部 Port `1433` → `10.1.0.200:1433` (現役 Windows)
- 遷移後需改為 `10.1.0.104:1433`
> 需確認 `/etc/nginx/nginx.conf` 最外層有 `stream { include /etc/nginx/stream.conf.d/*.conf; }`

### 全域代理參數 (`proxy-defaults.conf`)
對齊後端 Apache / PHP 設定，作用於 `http` 層級，所有 server block 均自動繼承：

| Nginx 參數 | 設定值 | 對應後端設定 |
|---|---|---|
| `client_max_body_size` | `128M` | PHP `upload_max_filesize` / `post_max_size` = 128M |
| `proxy_read_timeout` | `120s` | PHP `max_execution_time` = 120s |
| `proxy_send_timeout` | `120s` | PHP `max_execution_time` = 120s |
| `proxy_buffer_size` | `16k` | PHP `memory_limit` = 512M（減少暫存檔寫入）|
| `proxy_buffers` | `8 32k` | 同上 |
| `proxy_busy_buffers_size` | `64k` | 同上 |

> **注意：** 若個別 `server` 或 `location` 區塊有明確設定同名指令，則以該層設定覆蓋全域值。

## 使用方式

### 修改設定檔並同步
```bash
cd ~/bothwell-nginx
# 編輯 conf.d/ 或 stream.d/ 內的設定檔
./sync.sh
```
腳本會自動：
1. 將變更加入 Git 追蹤 (`git add .`)
2. 詢問並進行 Commit（未輸入則使用時間戳）
3. 將設定檔同步至系統 `/etc/nginx/` 對應目錄
4. 執行 `nginx -t` 檢查語法
5. 檢查通過後執行 `nginx -s reload`

## DuckDNS 動態 IP 自動更新

腳本位置：`~/bothwell-nginx/duckdns-update.sh`

此腳本會同時更新兩個子網域的 IP：
- `amee-bw.duckdns.org`
- `bw-internal.duckdns.org`

更新頻率：**每 5 分鐘**（由 crontab 管理）

查看 crontab：
```bash
crontab -l
```

查看更新 Log：
```bash
cat /var/log/duckdns-update.log
```

手動執行更新：
```bash
~/bothwell-nginx/duckdns-update.sh
```

## SSL 憑證管理

### amee-bw.duckdns.org
- 驗證方式：HTTP-01（需對外 80 Port 可達）
- 自動續簽：由 Certbot systemd timer 管理

### bw-internal.duckdns.org
- 驗證方式：DNS-01（DuckDNS API，不需要對外可達）
- 憑證憑據：`/etc/letsencrypt/duckdns/credentials.ini`（不在 Git 追蹤中）
- 自動續簽：由 Certbot systemd timer 管理

測試自動續簽：
```bash
sudo certbot renew --dry-run
```

### Certbot 修改後回寫備份
Certbot 自動修改系統 `/etc/nginx/conf.d/` 後，請記得回寫到本專案：
```bash
cp /etc/nginx/conf.d/<檔名>.conf ~/bothwell-nginx/conf.d/
cd ~/bothwell-nginx
git add .
git commit -m "[docs(nginx):同步Certbot更新後的設定]"
git push origin main
```

## 本地 DNS 伺服器 (dnsmasq)

為防止外網中斷時內部程式無法解析 DuckDNS 域名，這台 LXC 上同時跑了 dnsmasq 作為內網 DNS 伺服器。

### 運作邏輯

```
外網正常時：
  內網設備 → 查詢 dnsmasq (10.1.0.102) → 直接回傳本地 IP (192.168.246.251)
  其他域名 → 轉發給 8.8.8.8 / 1.1.1.1 正常解析

外網中斷時：
  兩個 DuckDNS 域名 → dnsmasq 仍回傳本地 IP → 服務不受影響
  其他域名 → 解析失敗（正常，外網本來就斷了）
```

### dnsmasq 設定
- 設定檔：`/etc/dnsmasq.d/bothwell.conf`（備份於 `dnsmasq/bothwell.conf`）
- 監聽介面：`eth1` (10.1.0.102) 與 `lo`
- 上游 DNS：`8.8.8.8` / `1.1.1.1`

### 定期從 DuckDNS 同步真實 IP (`duckdns-sync.sh`)
- 腳本：`~/bothwell-nginx/duckdns-sync.sh`
- 每 5 分鐘向 `8.8.8.8` 查詢 DuckDNS 的真實 IP
- 若 IP 有變更，自動更新 dnsmasq 設定並 reload
- 若外網不通（查詢回傳空值），**自動跳過，保留既有設定**（這是關鍵的離線保護機制）
- Log：`/var/log/duckdns-sync.log`

### 路由器設定（讓整個 LAN 都使用這台 DNS）
進入路由器管理介面，找到 **DHCP 設定** → **DNS 伺服器**，改成：
```
DNS1: 10.1.0.102
DNS2: 8.8.8.8  (備援)
```
設定後，LAN 上的所有設備都會自動走這台 dnsmasq 解析域名。

### 手動測試
```bash
# 測試 dnsmasq 是否正確回應
dig +short amee-bw.duckdns.org @10.1.0.102
dig +short bw-internal.duckdns.org @10.1.0.102

# 查看同步 Log
cat /var/log/duckdns-sync.log
```

## Git Commit 規範
所有 Commit 訊息統一使用格式：`[動作(項目):繁中說明]`

| 動作 | 說明 |
|---|---|
| `feat` | 新增功能或反代規則 |
| `fix` | 修正錯誤 |
| `update` | 更新既有配置 |
| `docs` | 修改文件 |
