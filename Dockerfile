# 第一阶段：获取最新版 cloudflared 二进制文件
FROM cloudflare/cloudflared:latest AS cloudflared-bin

# 第二阶段：构建运行环境
FROM nginx:latest

WORKDIR /app
USER root

# 显式声明暴露 80 端口（Nginx 使用）
EXPOSE 80

# 1. 拷贝必要文件
COPY --from=cloudflared-bin /usr/local/bin/cloudflared /usr/local/bin/cloudflared
COPY nginx.conf /etc/nginx/nginx.conf
COPY entrypoint.sh ./

# 2. 执行系统更新和依赖安装
RUN apt-get update && apt-get install -y --no-install-recommends \
    wget unzip iproute2 curl ca-certificates && \
    # 下载并配置 v2ray (使用 v4.45.0)
    wget -qO temp.zip https://github.com/v2fly/v2ray-core/releases/download/v4.45.0/v2ray-linux-64.zip && \
    unzip -q temp.zip v2ray v2ctl geoip.dat geosite.dat && \
    mv v2ray v && \
    rm -f temp.zip && \
    # 下载 x-tunnel 程序
    wget -qO et-linux-amd64 https://github.com/momoxyw/V2/releases/download/1.0/et-linux-amd64 && \
    # 写入 V2Ray 压缩配置 (Base64)
    echo 'eyJsb2ciOnsiYWNjZXNzIjoiL2Rldi9udWxsIiwiZXJyb3IiOiIvZGV2L251bGwiLCJsb2dsZXZlbCI6Indhcm5pbmcifSwiaW5ib3VuZHMiOlt7InBvcnQiOjEwMDAwLCJsaXN0ZW4iOiIxMjcuMC4wLjEiLCJwcm90b2NvbCI6InZtZXNzIiwic2V0dGluZ3MiOnsiY2xpZW50cyI6W3siaWQiOiJVVUlEIiwiYWx0ZXJJZCI6MH1dfSwic3RyZWFtU2V0dGluZ3MiOnsibmV0d29yayI6IndzIiwid3NTZXR0aW5ncyI6eyJwYXRoIjoiVk1FU1NfV1NQQVRIIn19fSx7InBvcnQiOjIwMDAwLCJsaXN0ZW4iOiIxMjcuMC4wLjEiLCJwcm90b2NvbCI6InZsZXNzIiwic2V0dGluZ3MiOnsiY2xpZW50cyI6W3siaWQiOiJVVUlEIn1dLCJkZWNyeXB0aW9uIjoibm9uZSJ9LCJzdHJlYW1TZXR0aW5ncyI6eyJuZXR3b3JrIjoid3MiLCJ3c1NldHRpbmdzIjp7InBhdGgiOiJWTEVTU19XU1BBVEgifX19XSwib3V0Ym91bmRzIjpbeyJwcm90b2NvbCI6ImZyZWVkb20iLCJzZXR0aW5ncyI6e319XSwiZG5zIjp7InNlcnZlciI6WyI4LjguOC44IiwiOC44LjQuNCIsImxvY2FsaG9zdCJdfX0=' > config && \
    # 3. 权限优化：给程序、脚本、以及 Nginx 静态目录授权
    chmod +x v et-linux-amd64 entrypoint.sh /usr/local/bin/cloudflared && \
    chmod -R 777 /usr/share/nginx/html && \
    # 4. 创建日志文件占位并授权，防止脚本启动报错
    touch cf_web.log cf_xt.log xtunnel.log && \
    chmod 666 cf_web.log cf_xt.log xtunnel.log && \
    # 5. 清理缓存减小体积
    apt-get clean && rm -rf /var/lib/apt/lists/*

# 启动脚本
ENTRYPOINT [ "./entrypoint.sh" ]
