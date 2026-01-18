# 阶段 1: 从官方镜像提取 cloudflared 二进制文件
FROM cloudflare/cloudflared:latest AS cloudflared-bin

# 阶段 2: 主镜像
FROM nginx:latest

# 设置工作目录和权限
WORKDIR /app
USER root

# 开放 Nginx 默认端口
EXPOSE 80

# 从第一阶段拷贝 cloudflared (免去配置 GPG 密钥的麻烦)
COPY --from=cloudflared-bin /usr/local/bin/cloudflared /usr/local/bin/cloudflared

# 拷贝配置文件和启动脚本 (请确保这两个文件在你的当前目录下)
COPY nginx.conf /etc/nginx/nginx.conf
COPY entrypoint.sh ./

# 合并所有安装逻辑以减小镜像层数
RUN apt-get update && apt-get install -y wget unzip iproute2 curl ca-certificates && \
    # 下载 v2ray
    wget -O temp.zip https://github.com/v2fly/v2ray-core/releases/download/v4.45.0/v2ray-linux-64.zip && \
    unzip temp.zip v2ray v2ctl geoip.dat geosite.dat && \
    mv v2ray v && \
    # 下载 et-linux-amd64
    wget -O et-linux-amd64 https://github.com/momoxyw/V2/releases/download/1.0/et-linux-amd64 && \
    rm -f temp.zip && \
    # 修正配置写入方式：使用单引号包含整个 Base64 字符串
    echo 'eyJsb2ciOnsiYWNjZXNzIjoiL2Rldi9udWxsIiwiZXJyb3IiOiIvZGV2L251bGwiLCJsb2dsZXZlbCI6Indhcm5pbmcifSwiaW5ib3VuZHMiOlt7InBvcnQiOjEwMDAwLCJsaXN0ZW4iOiIxMjcuMC4wLjEiLCJwcm90b2NvbCI6InZtZXNzIiwic2V0dGluZ3MiOnsiY2xpZW50cyI6W3siaWQiOiJVVUlEIiwiYWx0ZXJJZCI6MH1dfSwic3RyZWFtU2V0dGluZ3MiOnsibmV0d29yayI6IndzIiwid3NTZXR0aW5ncyI6eyJwYXRoIjoiVk1FU1NfV1NQQVRIIn19fSx7InBvcnQiOjIwMDAwLCJsaXN0ZW4iOiIxMjcuMC4wLjEiLCJwcm90b2NvbCI6InZsZXNzIiwic2V0dGluZ3MiOnsiY2xpZW50cyI6W3siaWQiOiJVVUlEIn1dLCJkZWNyeXB0aW9uIjoibm9uZSJ9LCJzdHJlYW1TZXR0aW5ncyI6eyJuZXR3b3JrIjoid3MiLCJ3c1NldHRpbmdzIjp7InBhdGgiOiJWTEVTU19XU1BBVEgifX19XSwib3V0Ym91bmRzIjpbeyJwcm90b2NvbCI6ImZyZWVkb20iLCJzZXR0aW5ncyI6e319XSwiZG5zIjp7InNlcnZlciI6WyI4LjguOC44IiwiOC44LjQuNCIsImxvY2FsaG9zdCJdfX0=' > config
    chmod -v 755 v v2ctl et-linux-amd64 entrypoint.sh /usr/local/bin/cloudflared && \
    apt-get clean && rm -rf /var/lib/apt/lists/*

# 启动脚本
ENTRYPOINT [ "./entrypoint.sh" ]
