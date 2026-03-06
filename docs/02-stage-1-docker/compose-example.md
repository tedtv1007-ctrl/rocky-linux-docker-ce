# Docker Compose 測試範例

這個範例將啟動一個簡單的 Nginx 網頁伺服器，用來驗證 Docker Compose 是否安裝成功且運作正常。

## 1. 建立測試目錄
```bash
mkdir docker-test && cd docker-test
```

## 2. 建立 docker-compose.yml
建立一個名為 `docker-compose.yml` 的檔案，內容如下：

```yaml
services:
  web:
    image: nginx:latest
    ports:
      - "8080:80"
    restart: always
```

## 3. 啟動服務
使用 Docker Compose 啟動容器（加上 `-d` 參數在背景執行）：

```bash
docker compose up -d
```

## 4. 驗證
開啟瀏覽器訪問 `http://你的IP:8080`，或者在終端機執行：

```bash
curl localhost:8080
```

如果看到 Nginx 的歡迎畫面，代表 Docker Compose 運作完美！

## 5. 停止並移除服務
測試完成後，可以執行以下指令清理環境：

```bash
docker compose down
```
