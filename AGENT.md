# Nginx 管理 Agent 指南 (AGENT.md)

這份文件是專為未來接手的 AI Agent 所寫的系統上下文及維護指南。當你被要求修改此 Nginx 反向代理專案時，請務必先閱讀此文件。

## 專案核心設計
此專案的目的是集中化管理 Nginx 設定檔，並強制使用 Git 版本控制。
所有的 Nginx 設定變更 **必須** 在此目錄 (`~/bothwell-nginx`) 完成，再透過 `sync.sh` 發布至系統目錄，**絕對不要** 直接修改系統 `/etc/nginx/` 裡的檔案，除非是 Certbot 的自動化修改需要被手動反向拉回。

## 目前環境參數
- **外部 Domain**: `amee-bw.duckdns.org`
- **本機 Nginx**: `10.1.0.102`
- **服務節點與遷移狀態**:
  1. `Windows XAMPP` (目前 `/` 的代理目標): `10.1.0.200:80` & `443`
  2. `LXC XAMPP` (目前 `/test/` 的代理目標，未來可能取代前者): `10.1.0.100:80` & `443`
  3. `FastAPI`: `10.1.0.101:80` (依需求於 `.conf` 中配置特定 path 即可開啟)
  4. `SQL Server` (`1433` port TCP 代理):
     - 目前：`10.1.0.200:1433`
     - 未來 (LXC)：`10.1.0.104:1433`

## Nginx 設定結構
本專案分為兩種不同類型的配置：
1. `conf.d/*.conf`: 這是 HTTP/HTTPS 相關的反向代理設定。對應系統為 `/etc/nginx/conf.d/`。
2. `stream.d/*.conf`: 這是基於 TCP/UDP 的第四層代理 (如 SQL Server 的 1433)。對應系統為 `/etc/nginx/stream.d/`。
   > 提醒：若 Nginx 報錯表示不認識 stream，表示系統的 `/etc/nginx/nginx.conf` 尚未開啟 stream 支援。請確保 `nginx.conf` 最外層有加入 `stream { include /etc/nginx/stream.d/*.conf; }`。

## 操作流程
1. 使用編輯器或腳本修改 `conf.d/` 或 `stream.d/` 內的檔案。
2. 執行 `./sync.sh`。該腳本會：
   - 執行 `git add .`
   - 要求使用者輸入 Commit Message (或直接按下 Enter 使用預設訊息)
   - 將檔案複製到系統 `/etc/nginx/` 對應目錄 (使用 `sudo`)
   - 執行 `nginx -t`
   - 執行 `nginx -s reload`
3. 任何結構變動或是網路架構改變，請同步更新本 `AGENT.md` 以及 `README.md`。

## HTTPS / SSL 備註
- 此環境預計需要配置 SSL 憑證。建議使用 Let's Encrypt (`certbot --nginx`) 來進行配置。
- 當使用者要求「配置 SSL」時，請提醒使用者透過系統終端執行 certbot，並在完成後，將 `/etc/nginx/conf.d/amee-bw.duckdns.org.conf` 被 certbot 修改過的新內容覆蓋回此專案的 `conf.d/amee-bw.duckdns.org.conf` 內，最後做一次 Git Commit。
