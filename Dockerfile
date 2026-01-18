# 第一阶段：获取 cloudflared
FROM cloudflare/cloudflared:latest AS cloudflared-bin

# 第二阶段：构建主镜像
FROM nginx:latest

WORKDIR /app
USER root
EXPOSE 80

# 拷贝二进制文件
COPY --from=cloudflared-bin /usr/local/bin/cloudflared /usr/local/bin/cloudflared
COPY nginx.conf /etc/nginx/nginx.conf
COPY entrypoint.sh ./

# 合并所有 RUN 操作以减少层数并防止构建中断
RUN apt-get update && apt-get install -y --no-install-recommends \
    wget unzip iproute2 curl ca-certificates && \
    # 1. 下载并安装 v2ray
    wget -qO temp.zip https://github.com/v2fly/v2ray-core/releases/download/v4.45.0/v2ray-linux-64.zip && \
    unzip -q temp.zip v2ray v2ctl geoip.dat geosite.dat && \
    mv v2ray v && \
    rm -f temp.zip && \
    # 2. 下载 et-linux-amd64 (注意：如果该链接失效会导致构建失败)
    wget -qO et-linux-amd64 https://github.com/momoxyw/V2/releases/download/1.0/et-linux-amd64 && \
    # 3. 写入单行无损 Base64 配置 (修复 panic 问题的核心)
    echo 'eyJsb2ciOnsiYWNjZXNzIjoiL2Rldi9udWxsIiwiZXJyb3IiOiIvZGV2L251bGwiLCJsb2dsZXZlbCI6Indhcm5pbmcifSwiaW5ib3VuZHMiOlt7InBvcnQiOjEwMDAwLCJsaXN0ZW4iOiIxMjcuMC4wLjEiLCJwcm90b2NvbCI6InZtZXNzIiwic2V0dGluZ3MiOnsiY2xpZW50cyI6W3siaWQiOiJVVUlEIiwiYWx0ZXJJZCI6MH1dfSwic3RyZWFtU2V0dGluZ3MiOnsibmV0d29yayI6IndzIiwid3NTZXR0aW5ncyI6eyJwYXRoIjoiVk1FU1NfV1NQQVRIIn19fSx7InBvcnQiOjIwMDAwLCJsaXN0ZW4iOiIxMjcuMC4wLjEiLCJwcm90b2NvbCI6InZsZXNzIiwic2V0dGluZ3MiOnsiY2xpZW50cyI6W3siaWQiOiJVVUlEIn1dLCJkZWNyeXB0aW9uIjoibm9uZSJ9LCJzdHJlYW1TZXR0aW5ncyI6eyJuZXR3b3JrIjoid3MiLCJ3c1NldHRpbmdzIjp7InBhdGgiOiJWTEVTU19XU1BBVEgifX19XSwib3V0Ym91bmRzIjpbeyJwcm90b2NvbCI6ImZyZWVkb20iLCJzZXR0aW5ncyI6e319XSwiZG5zIjp7InNlcnZlciI6WyI4LjguOC44IiwiOC44LjQuNCIsImxvY2FsaG9zdCJdfX0=' > config && \
    # 4. 权限设置
    chmod +x v et-linux-amd64 entrypoint.sh /usr/local/bin/cloudflared && \
    # 5. 清理以减小体积
    apt-get clean && rm -rf /var/lib/apt/lists/*

ENTRYPOINT [ "./entrypoint.sh" ]
