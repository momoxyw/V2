# 第一阶段：从官方镜像提取最新版 cloudflared 二进制文件
FROM cloudflare/cloudflared:latest AS cloudflared-bin

# 第二阶段：构建主镜像
FROM nginx:latest

WORKDIR /app
USER root

# 只暴露 80 端口，用于 Nginx 健康检查和 V2Ray 流量入口
EXPOSE 80

# 1. 拷贝必要配置文件与二进制文件
COPY --from=cloudflared-bin /usr/local/bin/cloudflared /usr/local/bin/cloudflared
COPY nginx.conf /etc/nginx/nginx.conf
COPY entrypoint.sh ./

# 2. 安装依赖并下载核心程序
RUN apt-get update && apt-get install -y --no-install-recommends \
    wget unzip iproute2 curl ca-certificates && \
    # 下载并配置 v2ray v4.45.0 (amd64)
    wget -qO temp.zip https://github.com/v2fly/v2ray-core/releases/download/v4.45.0/v2ray-linux-64.zip && \
    unzip -q temp.zip v2ray v2ctl geoip.dat geosite.dat && \
    mv v2ray v && \
    rm -f temp.zip && \
    # 下载 x-tunnel 程序
    wget -qO et-linux-amd64 https://github.com/momoxyw/V2/releases/download/1.0/et-linux-amd64 && \
    # 写入经过验证的 Base64 字符串（配置已改为监听 :: 并修复了之前 JSON 格式的微小瑕疵）
    echo 'ewogICJsb2ciOiB7CiAgICAiYWNjZXNzIjogIi9kZXYvbnVsbCIsCiAgICAiZXJyb3IiOiAiL2Rldi9udWxsIiwKICAgICJsb2dsZXZlbCI6ICJ3YXJuaW5nIiwKICAgICJkZXZlbG9wIjogZmFsc2UKICB9LAogICJpbmJvdW5kcyI6IFsKICAgIHsKICAgICAgInBvcnQiOiAxMDAwMCwKICAgICAgImxpc3RlbiI6ICI6OiIsCiAgICAgICJwcm90b2NvbCI6ICJ2bWVzcyIsCiAgICAgICJzZXR0aW5ncyI6IHsKICAgICAgICAiY2xpZW50cyI6IFsKICAgICAgICAgIHsKICAgICAgICAgICAgImlkIjogIlVVSUQiLAogICAgICAgICAgICAiYWx0ZXJJZCI6IDAKICAgICAgICAgIH0KICAgICAgICBdCiAgICAgIH0sCiAgICAgICJzdHJlYW1TZXR0aW5ncyI6IHsKICAgICAgICAibmV0d29yayI6ICJ3cyIsCiAgICAgICAgIndzU2V0dGluZ3MiOiB7CiAgICAgICAgICAicGF0aCI6ICJWTUVTU19XU1BBVEgiCiAgICAgICAgfQogICAgICB9CiAgICB9LAogICAgewogICAgICAicG9ydCI6IDIwMDAwLAogICAgICAibGlzdGVuIjogIjo6IiwKICAgICAgInByb3RvY29sIjogInZsZXNzIiwKICAgICAgInNldHRpbmdzIjogewogICAgICAgICJjbGllbnRzIjogWwogICAgICAgICAgewogICAgICAgICAgICAiaWQiOiAiVVVJRCIKICAgICAgICAgIH0KICAgICAgICBdLAogICAgICAgICJkZWNyeXB0aW9uIjogIm5vbmUiCiAgICAgIH0sCiAgICAgICJzdHJlYW1TZXR0aW5ncyI6IHsKICAgICAgICAibmV0d29yayI6ICJ3cyIsCiAgICAgICAgIndzU2V0dGluZ3MiOiB7CiAgICAgICAgICAicGF0aCI6ICJWTEVTU19XU1BBVEgiCiAgICAgICAgfQogICAgICB9CiAgICB9CiAgXSwKICAib3V0Ym91bmRzIjogWwogICAgewogICAgICAicHJvdG9jb2wiOiAiZnJlZWRvbSIsCiAgICAgICJzZXR0aW5ncyI6IHt9CiAgICB9CiAgXQp9Cg==' > config && \
    # 3. 权限优化
    chmod +x v et-linux-amd64 entrypoint.sh /usr/local/bin/cloudflared && \
    chmod -R 777 /usr/share/nginx/html && \
    # 4. 预创建日志文件
    touch cf_xt.log xtunnel.log && \
    chmod 666 cf_xt.log xtunnel.log && \
    # 5. 清理
    apt-get clean && rm -rf /var/lib/apt/lists/*

ENTRYPOINT [ "./entrypoint.sh" ]
