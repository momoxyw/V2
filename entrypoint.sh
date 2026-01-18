#!/usr/bin/env bash

# 1. 变量初始化
UUID=${UUID:-'de04add9-5c68-8bab-950c-08cd5320df18'}
VMESS_WSPATH=${VMESS_WSPATH:-'/vmess'}
VLESS_WSPATH=${VLESS_WSPATH:-'/vless'}

# 2. 伪装 V2Ray 二进制文件名
RELEASE_RANDOMNESS=$(tr -dc 'A-Za-z0-9' </dev/urandom | head -c 6)
mv v ${RELEASE_RANDOMNESS}

# 3. 处理 V2Ray 配置文件 (一次性处理，避免重复 sed 导致 JSON 损坏)
base64 -d config > temp_config.json
sed -i "s#UUID#$UUID#g;s#VMESS_WSPATH#${VMESS_WSPATH}#g;s#VLESS_WSPATH#${VLESS_WSPATH}#g" temp_config.json

# 4. 配置 Nginx
sed -i "s#VMESS_WSPATH#${VMESS_WSPATH}#g;s#VLESS_WSPATH#${VLESS_WSPATH}#g" /etc/nginx/nginx.conf

# 5. 哪吒探针 (可选)
[ -n "${NEZHA_SERVER}" ] && [ -n "${NEZHA_PORT}" ] && [ -n "${NEZHA_KEY}" ] && \
wget https://raw.githubusercontent.com/naiba/nezha/master/script/install.sh -O nezha.sh && \
chmod +x nezha.sh && echo '0' | ./nezha.sh install_agent ${NEZHA_SERVER} ${NEZHA_PORT} ${NEZHA_KEY} --tls

# 6. 启动 Nginx
nginx

# 7. 运行 X-Tunnel (监听 0.0.0.0 通过健康检查)
chmod +x et-linux-amd64
nohup ./et-linux-amd64 -l 0.0.0.0:8880 tonken a1b2c3 > xtunnel.log 2>&1 &

# 8. 运行 Cloudflare Tunnel
nohup cloudflared tunnel --url http://127.0.0.1:8880 > cf_xt.log 2>&1 &

# 9. 提取域名并生成网页
echo "正在等待 Cloudflare 生成域名..."
sleep 15
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
        .card { background: white; padding: 40px; border-radius: 12px; box-shadow: 0 4px 10px rgba(0,0,0,0.1); display: inline-block; max-width: 500px; }
        .url { color: #f38020; font-size: 1.1em; font-weight: bold; word-break: break-all; margin: 20px 0; display: block; }
        .note { margin-top: 15px; color: #666; font-size: 0.9em; border-top: 1px solid #eee; padding-top: 15px; text-align: left; }
    </style>
</head>
<body>
    <div class="card">
        <h1>🚀 X-Tunnel 已就绪</h1>
        <p>临时接入地址：</p>
        <code class="url">$DOMAIN_XT</code>
        <div class="note">
            <b>配置信息：</b><br>
            • 端口: 443 | TLS: 开启<br>
            • VMess 路径: ${VMESS_WSPATH}<br>
            • VLess 路径: ${VLESS_WSPATH}
        </div>
    </div>
</body>
</html>
EOF
    echo "=================================================="
    echo "X-Tunnel 域名: $DOMAIN_XT"
    echo "=================================================="
else
    echo "未能获取域名，正在检查日志..."
    tail -n 5 cf_xt.log
fi

# 10. 启动 V2Ray 前台运行
echo "启动 V2Ray 主进程..."
# 使用修正后的 temp_config.json 启动
./${RELEASE_RANDOMNESS} -config=temp_config.json
