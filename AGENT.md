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
- `amee-bw.duckdns.org`：使用 HTTP-01 驗證申請，需要對外 80 port 可達。Renewal 設定用 `authenticator = nginx` + `installer = nginx`，續簽後會**自動 reload Nginx**。
- `bw-internal.duckdns.org`：使用 DNS-01 驗證申請（certbot-dns-duckdns 插件），憑據在 `/etc/letsencrypt/duckdns/credentials.ini`（不在 Git 追蹤中）。Renewal 設定只有 `authenticator = dns-duckdns`，**沒有 installer**，續簽**不會自動 reload Nginx**。
- Certbot 自動修改系統設定後，**請將修改後的 `.conf` 複製回本專案 `conf.d/` 並 Git Commit 備份**。

### ⚠️ 重要陷阱：DNS-01 驗證不會自動 reload Nginx
2026-08-02 發生過的事故：`bw-internal.duckdns.org` 的憑證已經續簽成功（磁碟上有效期到 10 月），但 Nginx 從未被 reload，一直提供記憶體裡的舊憑證，直到那份舊憑證自然過期使用者才發現 502/憑證過期的問題。

**原因**：任何用 DNS-01（例如 `dns-duckdns` 插件）驗證的網域，Certbot 只負責簽發/更新憑證檔案本身，沒有 `installer` 的話完全不會去碰 Nginx 進程。這跟走 `authenticator = nginx` 的網域（如 `amee-bw`）行為不同，後者續簽後會自動 reload。

**已套用的修復**：在 `/etc/letsencrypt/renewal/bw-internal.duckdns.org.conf` 的 `[renewalparams]` 加上：
```
renew_hook = systemctl reload nginx
```

**未來規則（務必遵守）**：
1. 任何新增走 DNS-01 驗證的網域，簽發憑證後**必須**檢查其 `/etc/letsencrypt/renewal/<domain>.conf`，確保 `[renewalparams]` 內有 `renew_hook = systemctl reload nginx`（或等效的 deploy-hook）。
2. 若被要求排查「憑證過期」類問題，**不要只看 `certbot certificates`**（那只顯示磁碟檔案狀態）。務必額外用以下指令確認 Nginx 實際服務中的憑證：
   ```bash
   echo | openssl s_client -connect 127.0.0.1:443 -servername <domain> -no_ticket 2>/dev/null | openssl x509 -noout -dates
   ```
   兩者日期不一致就代表 Nginx 沒 reload，執行 `sudo nginx -t && sudo systemctl reload nginx` 即可修復當下問題，但別忘了同時檢查/補上 renew_hook 避免重演。

### ⚠️ 重要陷阱：414 Request-URI Too Large 與 large_client_header_buffers
2026-09-02 發生過的事故：`/api/v1/molds/status?mold_no=...` 帶約 300 筆 query string 參數時回傳 Nginx 原生的 `414 Request-URI Too Large`（回應是 nginx 錯誤頁，不是 FastAPI 回的，代表請求根本沒到後端）。

**原因**：`proxy-defaults.conf` 原本只對齊了後端 PHP 的上傳大小/逾時/proxy buffer，完全沒設定 `large_client_header_buffers`。Nginx 內建預設是 4 個 8k buffer，單一 request line（含完整 query string）必須塞進一個 buffer，超過 8k 就直接 414。

**已套用的修復**：在 `proxy-defaults.conf` 加上：
```
large_client_header_buffers 4 32k;
```

**未來規則（務必遵守）**：
1. 若被要求排查「414」或「API 帶大量參數失敗」，先確認回應是不是 Nginx 原生錯誤頁（`Server: nginx`，內容是純 HTML 標題），若是，代表請求連後端都沒送到，優先檢查 `large_client_header_buffers` / `client_header_buffer_size`，不要往後端 (FastAPI/PHP) 方向找。
2. 判斷方式：估算 `GET <path>?<querystring> HTTP/1.1` 這行的總 byte 數是否接近或超過目前設定值。
3. 若未來有 API 需要支援更大量的 query string 參數（例如上千筆 ID），可以再往上調 `large_client_header_buffers`，但更建議的長期方案是請後端改成 POST + body 傳遞大量參數，避免受 URL 長度限制反覆調參數。

## DuckDNS 自動更新 IP
- 腳本：`~/bothwell-nginx/duckdns-update.sh`
- 同時更新 `amee-bw` 與 `bw-internal` 兩個子網域
- 執行頻率：每 5 分鐘（crontab）
- Log：`/var/log/duckdns-update.log`
