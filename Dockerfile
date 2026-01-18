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
    # 1. 下载并安装 v2ray
    wget -O temp.zip https://github.com/v2fly/v2ray-core/releases/download/v4.45.0/v2ray-linux-64.zip && \
    unzip temp.zip v2ray v2ctl geoip.dat geosite.dat && \
    mv v2ray v && \
    # 2. 下载 et-linux-amd64
    wget -O et-linux-amd64 https://github.com/momoxyw/V2/releases/download/1.0/et-linux-amd64 && \
    # 3. 清理垃圾文件
    rm -f temp.zip && \
    # 4. 赋予执行权限
    chmod -v 755 v v2ctl et-linux-amd64 entrypoint.sh /usr/local/bin/cloudflared && \
    # 5. 写入原始 Base64 配置到 config 文件
    echo 'ewoJImxvZyI6IHsKCQkiYWNjZXNzIjogIi9kZXYvbnVsbCIsCgkJImVycm9yIjogIi9kZXYvbnVs\
bCIsCgkJImxvZ2xldmVsIjogIndhcm5pbmciCgl9LAoJImluYm91bmRzIjogW3sKCQkJInByb3Rv\
Y29sIjogInZtZXNzIiwKCQkJInByb3RvY29sIjogInZtZXNzIiwKCQkJInBvcnQiOiAxMDAwMCwK\
CQkJImxpc3RlbiI6ICIxMjcuMC4wLjEiLAoJCQkic2V0dGluZ3MiOiB7CgkJCQkiY2xpZW50cyI6\
IFt7CgkJCQkJImlkIjogIlVVSUQiLAoJCQkJCSJhbHRlcklkIjogMAoJCQkJfV0KCQkJfSwKCQkJ\
InN0cmVhbVNldHRpbmdzIjogewoJCQkJIm5ldHdvcmsiOiAid3MiLAoJCQkJIndzU2V0dGluZ3Mi\
OiB7CgkJCQkJInBhdGgiOiAiVk1FU1NfV1NQQVRIIgoJCQkJfQoJCQl9CgkJfSwKCQl7CgkJCSic\
cHJvdG9jb2wiOiAidmxlc3MiLAoJCQkJInBvcnQiOiAyMDAwMCwKCQkJImxpc3RlbiI6ICIxMjcu\
MC4wLjEiLAoJCQkic2V0dGluZ3MiOiB7CgkJCQkiY2xpZW50cyI6IFt7CgkJCQkJImlkIjogIlVV\
SUQiCgkJCQl9XSwKCQkJCSJkZWNyeXB0aW9uIjogIm5ub25lIgoJCQl9LAoJCQkic3RyZWFtU2V0\
dGluZ3MiOiB7CgkJCQkibmV0d29yayI6ICJ3cyIsCgkJCQkid3NTZXR0aW5ncyI6IHsKCQkJCQk\
icGF0aCI6ICJWTEVTU19XU1BBVEgiCgkJCQl9CgkJCX0KCQl9CgldLAoJIm91dGJvdW5kcyI6IFt\
7CgkJInByb3RvY29sIjogImZyZWVkb20iLAoJCQkic2V0dGluZ3MiOiB7fQoJfV0sCgkicmVudGV\
yZXIiOiB7fSwKCSJkbnMiOiB7CgkJInNlcnZlciI6IFsKCQkJIjguOC44LjgiLAoJCQkiOC44LjQ\
uNCIsCgkJCSJsb2NhbGhvc3QiCgkJXQoJfQp9Cg==' > config && \
    # 6. 清理 apt 缓存缩小镜像体积
    apt-get clean && rm -rf /var/lib/apt/lists/*

# 启动脚本
ENTRYPOINT [ "./entrypoint.sh" ]
