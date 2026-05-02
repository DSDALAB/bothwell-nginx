#!/bin/bash

# 定義 Nginx 設定檔目錄 (預設為 /etc/nginx，請依系統實際情況修改)
NGINX_CONF_DIR="/etc/nginx/conf.d"
NGINX_STREAM_DIR="/etc/nginx/stream.conf.d"
REPO_DIR="$HOME/bothwell-nginx"

cd "$REPO_DIR" || exit 1

echo "檢查是否有變更..."
# 檢查是否有未提交的變更
if [[ -n $(git status -s) ]]; then
    echo "發現變更，準備加入 git 追蹤..."
    git add .
    
    # 提示使用者輸入 commit 訊息，若無輸入則使用預設時間戳
    read -p "請輸入 Commit 訊息 (直接 Enter 使用預設時間): " COMMIT_MSG
    if [[ -z "$COMMIT_MSG" ]]; then
        COMMIT_MSG="Auto sync update $(date +'%Y-%m-%d %H:%M:%S')"
    fi
    
    git commit -m "$COMMIT_MSG"
    echo "Git 提交完成。"
else
    echo "無新變更，繼續執行同步..."
fi

echo "同步設定檔到 Nginx 目錄..."
# 確保目標目錄存在
sudo mkdir -p "$NGINX_CONF_DIR"
sudo mkdir -p "$NGINX_STREAM_DIR"

# 複製設定檔 (需 sudo 權限)
sudo cp -r "$REPO_DIR/conf.d/"* "$NGINX_CONF_DIR/" 2>/dev/null
sudo cp -r "$REPO_DIR/stream.d/"* "$NGINX_STREAM_DIR/" 2>/dev/null

echo "設定檔同步完成，開始驗證 Nginx 配置..."
sudo nginx -t

if [ $? -eq 0 ]; then
    echo "配置驗證成功，正在重新載入 Nginx..."
    sudo nginx -s reload
    echo "Nginx 重啟完成！"
else
    echo "Nginx 配置驗證失敗，請檢查設定檔內容！"
    exit 1
fi
