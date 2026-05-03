# Bothwell Nginx Reverse Proxy 管理

這個專案使用 Git 來統一管理 Nginx 的反向代理 (Reverse Proxy) 設定與 TCP 轉發 (Stream) 設定。

## 目錄結構
- `conf.d/`: 存放 HTTP / HTTPS 反向代理設定 (會同步到 `/etc/nginx/conf.d/`)
  - `amee-bw.duckdns.org.conf`: 公網域名設定 (HTTP + HTTPS)
  - `bw-internal.duckdns.org.conf`: 內網域名設定 (HTTP + HTTPS)
  - `direct-ip.conf`: 純 IP 直連設定 (HTTP only)
- `stream.d/`: 存放 TCP / UDP 轉發設定 (會同步到 `/etc/nginx/stream.conf.d/`)
- `sync.sh`: 設定檔同步腳本，提供自動 Git Commit、複製到系統目錄、驗證並重新載入 Nginx 配置。
- `duckdns-update.sh`: DuckDNS 動態 IP 自動更新腳本，由 crontab 每 5 分鐘自動執行。
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

## Git Commit 規範
所有 Commit 訊息統一使用格式：`[動作(項目):繁中說明]`

| 動作 | 說明 |
|---|---|
| `feat` | 新增功能或反代規則 |
| `fix` | 修正錯誤 |
| `update` | 更新既有配置 |
| `docs` | 修改文件 |
