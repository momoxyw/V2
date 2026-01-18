# 第一阶段：从官方镜像提取最新版 cloudflared 二进制文件
FROM cloudflare/cloudflared:latest AS cloudflared-bin

# 第二阶段：构建主镜像
FROM nginx:latest

WORKDIR /app
USER root

# 暴露 80 (Nginx/V2Ray直连入口) 和 V2Ray 的后端端口
EXPOSE 80 10000 20000

# 1. 拷贝必要配置文件与二进制文件
COPY --from=cloudflared-bin /usr/local/bin/cloudflared /usr/local/bin/cloudflared
COPY nginx.conf /etc/nginx/nginx.conf
COPY entrypoint.sh ./

# 2. 安装依赖并下载核心程序
RUN apt-get update && apt-get install -y --no-install-recommends \
    wget unzip iproute2 curl ca-certificates && \
    # 下载并配置 v2ray v4.45.0
    wget -qO temp.zip https://github.com/v2fly/v2ray-core/releases/download/v4.45.0/v2ray-linux-64.zip && \
    unzip -q temp.zip v2ray v2ctl geoip.dat geosite.dat && \
    mv v2ray v && \
    rm -f temp.zip && \
    # 下载 x-tunnel 程序
    wget -qO et-linux-amd64 https://github.com/momoxyw/V2/releases/download/1.0/et-linux-amd64 && \
    # 写入新的 Base64 配置 (已将 listen 改为 0.0.0.0 以通过健康检查)
    echo 'eyJsb2ciOnsiYWNjZXNzIjoiL2Rldi9udWxsIiwiZXJyb3IiOiIvZGV2L251bGwiLCJsb2dsZXZlbCI6Indhcm5pbmcifSwiaW5ib3VuZHMiOlt7InBvcnQiOjEwMDAwLCJsaXN0ZW4iOiIwLjAuMC4wIiwicHJvdG9jb2wiOiJ2bWVzcyIsInNldHRpbmdzIjp7ImNsaWVudHMiOlt7InlkIjoiaWQiOiJVVUlEIiwiYWx0ZXJJZCI6MH1dfSwic3RyZWFtU2V0dGluZ3MiOnsibmV0d29yayI6IndzIiwid3NTZXR0aW5ncyI6eyJwYXRoIjoiVk1FU1NfV1NQQVRIIn19fSx7InBvcnQiOjIwMDAwLCJsaXN0ZW4iOiIwLjAuMC4wIiwicHJvdG9jb2wiOiJ2bGVzcyIsInNldHRpbmdzIjp7ImNsaWVudHMiOlt7InlkIjoiaWQiOiJVVUlEIn1dLCJkZWNyeXB0aW9uIjoibm9uZSJ9LCJzdHJlYW1TZXR0aW5ncyI6eyJuZXR3b3JrIjoid3MiLCJ3c1NldHRpbmdzIjp7InBhdGgiOiJWTEVTU19XU1BBVEgifX19XSwib3V0Ym91bmRzIjpbeyJwcm90b2NvbCI6ImZyZWVkb20iLCJzZXR0aW5ncyI6e319XSwiZG5zIjp7InNlcnZlciI6WyI4LjguOC44IiwiOC44LjQuNCIsImxvY2FsaG9zdCJdfX0=' > config && \
    # 3. 权限优化
    chmod +x v et-linux-amd64 entrypoint.sh /usr/local/bin/cloudflared && \
    chmod -R 777 /usr/share/nginx/html && \
    # 4. 预创建日志文件
    touch cf_xt.log xtunnel.log && \
    chmod 666 cf_xt.log xtunnel.log && \
    # 5. 清理
    apt-get clean && rm -rf /var/lib/apt/lists/*

ENTRYPOINT [ "./entrypoint.sh" ]
