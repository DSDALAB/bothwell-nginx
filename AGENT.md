# Nginx 管理 Agent 指南 (AGENT.md)

這份文件是專為未來接手的 AI Agent 所寫的系統上下文及維護指南。當你被要求修改此 Nginx 反向代理專案時，請務必先閱讀此文件。

## 專案核心設計
此專案的目的是集中化管理 Nginx 設定檔，並強制使用 Git 版本控制。
所有的 Nginx 設定變更 **必須** 在此目錄 (`~/bothwell-nginx`) 完成，再透過 `sync.sh` 發布至系統目錄，**絕對不要** 直接修改系統 `/etc/nginx/` 裡的檔案，除非是 Certbot 的自動化修改需要被手動反向拉回。

## 目前環境參數
- **Nginx 主機 eth0 (Proxmox 內網)**: `192.168.246.251`
- **Nginx 主機 eth1 (LAN)**: `10.1.0.102`
- **對外公網 IP**: `220.135.228.168`
- **域名**:
  - `amee-bw.duckdns.org` → 公網 (`220.135.228.168`)
  - `bw-internal.duckdns.org` → 內網 (`192.168.246.251`，流量不出外網)
- **服務節點與遷移狀態**:
  1. `Windows XAMPP` (目前 `/` 的代理目標): `10.1.0.200:80` & `443`
  2. `LXC XAMPP` (目前 `/test/` 的代理目標，未來可能取代前者): `10.1.0.100:80` & `443`
  3. `FastAPI`: `10.1.0.101:80` (路徑原樣傳遞，不截斷 `/api/` 前綴)
  4. `SQL Server` (`1433` port TCP 代理):
     - 目前：`10.1.0.200:1433`
     - 未來 (LXC)：`10.1.0.104:1433`

## Nginx 設定結構
本專案分為兩種不同類型的配置：
1. `conf.d/*.conf`: 這是 HTTP/HTTPS 相關的反向代理設定。對應系統為 `/etc/nginx/conf.d/`。
2. `stream.d/*.conf`: 這是基於 TCP/UDP 的第四層代理 (如 SQL Server 的 1433)。對應系統為 `/etc/nginx/stream.conf.d/`。
   > 提醒：若 Nginx 報錯表示不認識 stream，表示系統的 `/etc/nginx/nginx.conf` 尚未開啟 stream 支援。請確保 `nginx.conf` 最外層有加入 `stream { include /etc/nginx/stream.conf.d/*.conf; }`。

## 操作流程
1. 使用編輯器或腳本修改 `conf.d/` 或 `stream.d/` 內的檔案。
2. 執行 `./sync.sh`。該腳本會：
   - 執行 `git add .`
   - 要求使用者輸入 Commit Message (或直接按下 Enter 使用預設訊息)
   - 將檔案複製到系統 `/etc/nginx/` 對應目錄 (使用 `sudo`)
   - 執行 `nginx -t`
   - 執行 `nginx -s reload`
3. 任何結構變動或是網路架構改變，請同步更新本 `AGENT.md` 以及 `README.md`。

> **強制規則：所有技術規格變更（新增域名、修改代理目標、新增服務、調整 SSL 設定等）都必須更新 `README.md`，確保文件與實際設定保持同步。**

## Git Commit 規範
未來的 Commit 訊息必須統一遵守以下格式：
`[動作(項目):繁中說明]`

**動作類型範例：**
- `feat`: 新增功能或新的反代規則
- `fix`: 修正錯誤或設定檔語法
- `update`: 更新既有配置或優化
- `docs`: 修改說明文件

**範例：**
- `[update(nginx):新增API反代]`
- `[feat(stream):加入新的資料庫轉發]`
- `[fix(ssl):修正憑證路徑錯誤]`

## HTTPS / SSL 備註
- `amee-bw.duckdns.org`：使用 HTTP-01 驗證申請，需要對外 80 port 可達。
- `bw-internal.duckdns.org`：使用 DNS-01 驗證申請（certbot-dns-duckdns 插件），憑據在 `/etc/letsencrypt/duckdns/credentials.ini`（不在 Git 追蹤中）。
- Certbot 自動修改系統設定後，**請將修改後的 `.conf` 複製回本專案 `conf.d/` 並 Git Commit 備份**。

## DuckDNS 自動更新 IP
- 腳本：`~/bothwell-nginx/duckdns-update.sh`
- 同時更新 `amee-bw` 與 `bw-internal` 兩個子網域
- 執行頻率：每 5 分鐘（crontab）
- Log：`/var/log/duckdns-update.log`
