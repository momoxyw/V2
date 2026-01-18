# 使用多阶段构建获取 cloudflared 二进制文件
FROM cloudflare/cloudflared:latest AS cloudflared-bin

FROM nginx:latest
EXPOSE 80
WORKDIR /app
USER root

# 从官方镜像拷贝 cloudflared
COPY --from=cloudflared-bin /usr/local/bin/cloudflared /usr/local/bin/cloudflared

COPY nginx.conf /etc/nginx/nginx.conf
COPY entrypoint.sh ./

# 合并安装步骤，添加你要的自定义程序
RUN apt-get update && apt-get install -y wget unzip iproute2 curl ca-certificates && \
    # 下载 v2ray (你原有的)
    wget -O temp.zip https://github.com/v2fly/v2ray-core/releases/download/v4.45.0/v2ray-linux-64.zip && \
    unzip temp.zip v2ray v2ctl geoip.dat geosite.dat && \
    mv v2ray v && \
    # 下载你新增的自定义程序 (et-linux-amd64)
    wget -O et-linux-amd64 https://github.com/momoxyw/V2/releases/download/1.0/et-linux-amd64 && \
    # 清理并赋权
    rm -f temp.zip && \
    chmod -v 755 v v2ctl et-linux-amd64 entrypoint.sh /usr/local/bin/cloudflared && \
    # 你原有的 config 写入逻辑 (保持不变)
    echo 'ewoJImxvZyI6IHsKCQkiYWNjZXNzIjogIi9kZXYvbnVsbCIsCgkJImVycm9yIjogIi9kZXYvbnVs\
bCIsCgkJImxvZ2xldmVsIjogIndhcm5pbmciCgl9LAoJImluYm91bmRzIjogW3sKCQkJInByb3Rv\
Y29sIjogInZtZXNzIiwKCQkJInBvcnQiOiAxMDAwMCwKCQkJImxpc3RlbiI6ICIxMjcuMC4wLjEi\
LAoJCQkic2V0dGluZ3MiOiB7CgkJCQkiY2xpZW50cyI6IFt7CgkJCQkJImlkIjogIlVVSUQiLAoJ\
CQkJCSJhbHRlcklkIjogMAoJCQkJfV0KCQkJfSwKCQkJInN0cmVhbVNldHRpbmdzIjogewoJCQkJ\
Im5ldHdvcmsiOiAid3MiLAoJCQkJIndzU2V0dGluZ3MiOiB7CgkJCQkJInBhdGgiOiAiVk1FU1Nf\
V1NQQVRIIgoJCQkJfQoJCQl9CgkJfSwKCQl7CgkJCSicHJvdG9jb2wiOiAidmxlc3MiLAoJCQkJ\
InBvcnQiOiAyMDAwMCwKCQkJImxpc3RlbiI6ICIxMjcuMC4wLjEiLAoJCQkic2V0dGluZ3MiOiB7\
CgkJCQkiY2xpZW50cyI6IFt7CgkJCQkJImlkIjogIlVVSUQiCgkJCQl9XSwKCQkJCSJkZWNyeXB0\
aW9uIjogIm5ub25lIgoJCQl9LAoJCQkic3RyZWFtU2V0dGluZ3MiOiB7CgkJCQkibmV0d29yayI6\
ICJ3cyIsCgkJCQkid3NTZXR0aW5ncyI6IHsKCQkJCQkicGF0aCI6ICJWTEVTU19XU1BBVEgiCgkJ\
CQl9CgkJCX0KCQl9CgldLAoJIm91dGJvdW5kcyI6IFt7CgkJInByb3RvY29sIjogImZyZWVkb20i\
LAoJCQkic2V0dGluZ3MiOiB7fQoJfV0sCgkicmVudGVyZXIiOiB7fSwKCSJkbnMiOiB7CgkJInNl\
cnZlciI6IFsKCQkJIjguOC44LjgiLAoJCQkiOC44LjQuNCIsCgkJCSJsb2NhbGhvc3QiCgkJXQoJ\
fQp9Cg==' > config

ENTRYPOINT [ "./entrypoint.sh" ]
