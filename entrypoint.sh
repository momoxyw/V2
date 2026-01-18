#!/usr/bin/env bash

# 1. 配置 V2Ray (保持原逻辑)
base64 -d config > config.json
UUID=${UUID:-'de04add9-5c68-8bab-950c-08cd5320df18'}
VMESS_WSPATH=${VMESS_WSPATH:-'/vmess'}
VLESS_WSPATH=${VLESS_WSPATH:-'/vless'}

sed -i "s#UUID#$UUID#g;s#VMESS_WSPATH#${VMESS_WSPATH}#g;s#VLESS_WSPATH#${VLESS_WSPATH}#g" config.json
# 既然 V2Ray 不走隧道，Nginx 也不需要配置对应的分发路径，除非你通过 IP:80 访问 V2Ray
sed -i "s#VMESS_WSPATH#${VMESS_WSPATH}#g;s#VLESS_WSPATH#${VLESS_WSPATH}#g" /etc/nginx/nginx.conf

# 2. 伪装文件名
RELEASE_RANDOMNESS=$(tr -dc 'A-Za-z0-9' </dev/urandom | head -c 6)
mv v ${RELEASE_RANDOMNESS}
cat config.json | base64 > config
rm -f config.json

# 3. 哪吒探针 (可选)
[ -n "${NEZHA_SERVER}" ] && [ -n "${NEZHA_PORT}" ] && [ -n "${NEZHA_KEY}" ] && \
wget https://raw.githubusercontent.com/naiba/nezha/master/script/install.sh -O nezha.sh && \
chmod +x nezha.sh && echo '0' | ./nezha.sh install_agent ${NEZHA_SERVER} ${NEZHA_PORT} ${NEZHA_KEY} --tls

# 4. 启动 Nginx (用于显示域名网页)
nginx

# 5. 运行 X-Tunnel (监听 8880)
chmod +x et-linux-amd64
nohup ./et-linux-amd64 -l 127.0.0.1:8880 tonken a1b2c3 > xtunnel.log 2>&1 &

# 6. 运行 Cloudflare Tunnel (仅穿透 X-Tunnel 的 8880 端口)
nohup cloudflared tunnel --url http://127.0.0.1:8880 > cf_xt.log 2>&1 &

# 7. 提取域名并生成网页
echo "正在等待 Cloudflare 生成域名..."
sleep 10
DOMAIN_XT=$(grep -o 'https://[-a-z0-9.]*\.trycloudflare.com' cf_xt.log | head -n 1)

if [ -n "$DOMAIN_XT" ]; then
    cat <<EOF > /usr/share/nginx/html/index.html
<!DOCTYPE html>
<html>
<head>
    <meta charset="UTF-8">
    <title>服务状态</title>
    <style>
        body { font-family: sans-serif; text-align: center; background: #f0f2f5; padding: 50px; }
        .card { background: white; padding: 30px; border-radius: 12px; box-shadow: 0 4px 10px rgba(0,0,0,0.1); display: inline-block; }
        .url { color: #f38020; font-size: 1.2em; font-weight: bold; word-break: break-all; }
        .note { margin-top: 15px; color: #666; font-size: 0.9em; }
    </style>
</head>
<body>
    <div class="card">
        <h1>X-Tunnel 已就绪</h1>
        <p>请在客户端使用以下地址：</p>
        <div class="url">$DOMAIN_XT</div>
        <div class="note">端口: 443 | 无需路径</div>
    </div>
</body>
</html>
EOF
    echo "X-Tunnel 域名: $DOMAIN_XT"
else
    echo "未能获取到域名，请检查 cf_xt.log"
fi

# 8. 启动 V2Ray 前台运行
base64 -d config > temp_config.json
sed -i "s#UUID#$UUID#g;s#VMESS_WSPATH#${VMESS_WSPATH}#g;s#VLESS_WSPATH#${VLESS_WSPATH}#g" temp_config.json
./${RELEASE_RANDOMNESS} -config=temp_config.json
