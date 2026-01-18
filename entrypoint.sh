#!/usr/bin/env bash

# 1. 环境准备与配置生成 (保持原逻辑)
base64 -d config > config.json
UUID=${UUID:-'de04add9-5c68-8bab-950c-08cd5320df18'}
VMESS_WSPATH=${VMESS_WSPATH:-'/vmess'}
VLESS_WSPATH=${VLESS_WSPATH:-'/vless'}
sed -i "s#UUID#$UUID#g;s#VMESS_WSPATH#${VMESS_WSPATH}#g;s#VLESS_WSPATH#${VLESS_WSPATH}#g" config.json
sed -i "s#VMESS_WSPATH#${VMESS_WSPATH}#g;s#VLESS_WSPATH#${VLESS_WSPATH}#g" /etc/nginx/nginx.conf

# 2. 伪装执行文件名称 (保持原逻辑)
RELEASE_RANDOMNESS=$(tr -dc 'A-Za-z0-9' </dev/urandom | head -c 6)
mv v ${RELEASE_RANDOMNESS}
cat config.json | base64 > config
rm -f config.json

# 3. 安装哪吒探针 (保持原逻辑)
[ -n "${NEZHA_SERVER}" ] && [ -n "${NEZHA_PORT}" ] && [ -n "${NEZHA_KEY}" ] && wget https://raw.githubusercontent.com/naiba/nezha/master/script/install.sh -O nezha.sh && chmod +x nezha.sh && echo '0' | ./nezha.sh install_agent ${NEZHA_SERVER} ${NEZHA_PORT} ${NEZHA_KEY} --tls

# 4. 启动 Nginx (后台运行)
nginx

# ================= 新增逻辑开始 =================

# 5. 运行自定义程序 x-tunnel (后台)
# 注意：确保 Dockerfile 中下载后的文件名一致，这里使用你要求的名字
chmod +x et-linux-amd64
nohup ./et-linux-amd64 -l ws://[::]:8880 tonken a1b2c3 > xtunnel.log 2>&1 &

# 6. 运行 cloudflared tunnel (后台)
nohup cloudflared tunnel --url http://127.0.0.1:8880 > cloudflared.log 2>&1 &

# 7. 等待并提取 Cloudflare 临时域名
echo "等待 Cloudflare 生成临时域名..."
sleep 8 # 给一点生成时间
CF_DOMAIN=$(grep -o 'https://[-a-z0-9.]*\.trycloudflare.com' cloudflared.log | head -n 1)

if [ -n "$CF_DOMAIN" ]; then
    echo "=================================================="
    echo "你的 Cloudflare 临时域名为: $CF_DOMAIN"
    echo "=================================================="
else
    echo "警告: 未能获取到临时域名，请检查容器网络或 cloudflared.log"
fi

# ================= 新增逻辑结束 =================

# 8. 运行 V2Ray (保持原逻辑，作为前台主进程)
base64 -d config > config.json
# 确保这里调用的是已经 mv 过的伪装名 $RELEASE_RANDOMNESS
./${RELEASE_RANDOMNESS} -config=config.json
