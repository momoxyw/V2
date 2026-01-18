# 第一阶段：从官方镜像提取最新版 cloudflared 二进制文件
FROM cloudflare/cloudflared:latest AS cloudflared-bin

# 第二阶段：构建主镜像
FROM nginx:latest

WORKDIR /app
USER root

# 只暴露 80 端口。V2Ray 直连流量将通过 Nginx 转发到内部 10000/20000 端口
EXPOSE 80

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
    # 写入校验过的 Base64 配置 (保持 0.0.0.0 监听但不对外暴露端口)
    echo 'ewogICJsb2ciOiB7CiAgICAiYWNjZXNzIjogIi9kZXYvbnVsbCIsCiAgICAiZXJyb3IiOiAiL2Rldi9udWxsIiwKICAgICJsb2dsZXZlbCI6ICJ3YXJuaW5nIiwKICAgICJkZXZlbG9wIjogZmFsc2UKICB9LAogICJpbmJvdW5kcyI6IFsKICAgIHsKICAgICAgInBvcnQiOiAxMDAwMCwKICAgICAgImxpc3RlbiI6ICIwLjAuMC4wIiwKICAgICAgInByb3RvY29sIjogInZtZXNzIiwKICAgICAgInNldHRpbmdzIjogewogICAgICAgICJjbGllbnRzIjogWwogICAgICAgICAgewogICAgICAgICAgICAiaWQiOiAiVVVJRCIsCiAgICAgICAgICAgICJhbHRlcklkIjogMAogICAgICAgICAgfQogICAgICAgIF0KICAgICAgfSwKICAgICAgInN0cmVhbVNldHRpbmdzIjogewogICAgICAgICJuZXR3b3JrIjogIndzIiwKICAgICAgICAid3NTZXR0aW5ncyI6IHsKICAgICAgICAgICJwYXRoIjogIlZNRVNTX1dTUEFUSCIKICAgICAgICB9CiAgICAgIH0KICAgIH0sCiAgICB7CiAgICAgICJwb3J0IjogMjAwMDAsCiAgICAgICJsaXN0ZW4iOiAiMC4wLjAuMCIsCiAgICAgICJwcm90b2NvbCI6ICJ2bGVzcyIsCiAgICAgICJzZXR0aW5ncyI6IHsKICAgICAgICAiY2xpZW50cyI6IFsKICAgICAgICAgIHsKICAgICAgICAgICAgImlkIjogIlVVSUQiCiAgICAgICAgICB9CiAgICAgICAgXSwKICAgICAgICAiZGVjcnlwdGlvbiI6ICJub25lIgogICAgICB9LAogICAgICAic3RyZWFtU2V0dGluZ3MiOiB7CiAgICAgICAgIm5ldHdvcmsiOiAid3MiLAogICAgICAgICJ3c1NldHRpbmdzIjogewogICAgICAgICAgInBhdGgiOiAiVkxFU1NfV1NQQVRIIgogICAgICAgIH0KICAgICAgfQogICAgfQogIF0sCiAgIm91dGJvdW5kcyI6IFsKICAgIHsKICAgICAgInByb3RvY29sIjogImZyZWVkb20iLAogICAgICAic2V0dGluZ3MiOiB7fQogICAgfQogIF0KfQo=' > config && \
    # 3. 权限优化
    chmod +x v et-linux-amd64 entrypoint.sh /usr/local/bin/cloudflared && \
    chmod -R 777 /usr/share/nginx/html && \
    # 4. 预创建日志文件
    touch cf_xt.log xtunnel.log && \
    chmod 666 cf_xt.log xtunnel.log && \
    # 5. 清理
    apt-get clean && rm -rf /var/lib/apt/lists/*

ENTRYPOINT [ "./entrypoint.sh" ]
