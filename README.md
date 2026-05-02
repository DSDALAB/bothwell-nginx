# Bothwell Nginx Reverse Proxy 管理

這個專案使用 Git 來統一管理 Nginx 的反向代理 (Reverse Proxy) 設定與 TCP 轉發 (Stream) 設定。

## 目錄結構
- `conf.d/`: 存放 HTTP / HTTPS 反向代理設定 (會同步到 `/etc/nginx/conf.d/`)
- `stream.d/`: 存放 TCP / UDP 轉發設定 (會同步到 `/etc/nginx/stream.d/`)
- `sync.sh`: 設定檔同步腳本，提供自動 Git Commit、複製到系統目錄、驗證並重新載入 Nginx 配置。
- `AGENT.md`: 提供給 AI Agent 參考的專案維護指南與上下文。

## 服務與網路配置
目前的網域為 `amee-bw.duckdns.org`，解析至此 Nginx 主機。

### 內部網路架構
- **Nginx 主機**: `10.1.0.102:80` (及 `443` HTTPS)
- **Windows XAMPP (現行)**: `10.1.0.200:80 & 443`
- **LXC XAMPP (未來遷移)**: `10.1.0.100:80 & 443`
- **FastAPI 服務**: `10.1.0.101:80`
- **Windows SQL Server (現行)**: `10.1.0.200:1433`
- **LXC SQL Server (未來遷移)**: `10.1.0.104:1433`

### 代理規則
- HTTP/HTTPS (`amee-bw.duckdns.org`):
  - `/` (根目錄) -> 轉發至 `10.1.0.200:80` (Windows XAMPP)
  - `/test/` -> 轉發至 `10.1.0.100:80` (LXC XAMPP)
  - FastAPI (`10.1.0.101`) -> 設定已預留於設定檔內，可依需求開啟指定路徑。
- TCP 轉發 (`1433` port):
  - 外部 `1433` -> 轉發至內部 `10.1.0.200:1433` (現行)，後續需改為 `10.1.0.104:1433`。

> **注意**：
> 要啟用 `stream.d/` 下的 TCP 代理，需確保系統中的主 `/etc/nginx/nginx.conf` 檔案的最外層 (和 http 同級) 包含以下區塊：
> ```nginx
> stream {
>     include /etc/nginx/stream.d/*.conf;
> }
> ```

## 使用方式
當你修改了任何 `.conf` 設定檔後，只需要執行：
```bash
./sync.sh
```
腳本將會自動：
1. 將變更加入 Git 追蹤 (`git add .`)
2. 詢問並進行 Commit (未輸入則使用時間戳)
3. 將設定檔同步至系統 `/etc/nginx/` 對應目錄
4. 執行 `nginx -t` 檢查語法
5. 檢查通過後執行 `nginx -s reload` 使設定生效

*(備註：原始需求提到同步至 `.ssh/config`，但考量為 Nginx 設定檔，腳本內已修正為同步至 Nginx 的系統設定目錄。若真的有 SSH ProxyJump 或其他 SSH 需求，請額外建立相關配置。)*

## SSL 簽證與自動續簽 (Certbot)
由於我們使用 `duckdns` 動態網域，且已將網域指向此主機：
1. **安裝 Certbot 與 Nginx 插件** (若尚未安裝):
   ```bash
   sudo apt update
   sudo apt install certbot python3-certbot-nginx
   ```
2. **申請 SSL 憑證** (由 Certbot 自動修改 Nginx 配置)：
   ```bash
   sudo certbot --nginx -d amee-bw.duckdns.org
   ```
3. **自動續簽**:
   Certbot 預設會寫入系統 cronjob 或 systemd timer，自動每 60 天續簽一次。
   可以透過以下指令測試自動續簽是否正常運作：
   ```bash
   sudo certbot renew --dry-run
   ```
4. **回寫備份**:
   當 Certbot 自動修改 `/etc/nginx/conf.d/amee-bw.duckdns.org.conf` 後，請記得將修改後的設定檔複製回 `~/bothwell-nginx/conf.d/` 並且透過 Git commit 備份下來。
