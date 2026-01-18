#!/usr/bin/env bash

# 1. 配置 V2Ray (保持原逻辑)
base64 -d config > config.json
UUID=${UUID:-'de04add9-5c68-8bab-950c-08cd5320df18'}
VMESS_WSPATH=${VMESS_WSPATH:-'/vmess'}
VLESS_WSPATH=${VLESS_WSPATH:-'/vless'}

# 替换配置中的 UUID 和路径
sed -i "s#UUID#$UUID#g;s#VMESS_WSPATH#${VMESS_WSPATH}#g;s#VLESS_WSPATH#${VLESS_WSPATH}#g" config.json
sed -i "s#VMESS_WSPATH#${VMESS_WSPATH}#g;s#VLESS_WSPATH#${VLESS_WSPATH}#g" /etc/nginx/nginx.conf

# 2. 伪装文件名
RELEASE_RANDOMNESS=$(tr -dc 'A-Za-z0-9' </dev/urandom | head -c 6)
mv v ${RELEASE_RANDOMNESS}
cat config.json | base64 > config
rm -f config.json

# 3. 哪吒探针 (如果有变量则安装)
[ -n "${NEZHA_SERVER}" ] && [ -n "${NEZHA_PORT}" ] && [ -n "${NEZHA_KEY}" ] && \
wget https://raw.githubusercontent.com/naiba/nezha/master/script/install.sh -O nezha.sh && \
chmod +x nezha.sh && echo '0' | ./nezha.sh install_agent ${NEZHA_SERVER} ${NEZHA_PORT} ${NEZHA_KEY} --tls

# 4. 启动 Nginx (用于显示域名网页和转发直连 V2Ray)
nginx

# 5. 运行 X-Tunnel
# 【修改点】监听地址改为 0.0.0.0 以便通过云平台的 TCP 端口检查
chmod +x et-linux-amd64
nohup ./et-linux-amd64 -l 0.0.0.0:8880 tonken a1b2c3 > xtunnel.log 2>&1 &

# 6. 运行 Cloudflare Tunnel
# 注意：这里依然指向 127.0.0.1:8880 或 0.0.0.0:8880 均可
nohup cloudflared tunnel --url http://127.0.0.1:8880 > cf_xt.log 2>&1 &

# 7. 提取域名并生成网页
echo "正在等待 Cloudflare 生成域名..."
sleep 12
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
        h1 { color: #333; }
        .url { color: #f38020; font-size: 1.2em; font-weight: bold; word-break: break-all; margin: 20px 0; display: block; }
        .note { margin-top: 15px; color: #666; font-size: 0.9em; border-top: 1px solid #eee; padding-top: 15px; }
        code { background: #eee; padding: 2px 4px; border-radius: 4px; }
    </style>
</head>
<body>
    <div class="card">
        <h1>🚀 X-Tunnel 已就绪</h1>
        <p>临时接入地址：</p>
        <a class="url" href="$DOMAIN_XT" target="_blank">$DOMAIN_XT</a>
        <div class="note">
            <b>配置说明：</b><br>
            端口: <code>443</code> | 路径: <code>(留空)</code><br><br>
            <b>直连 V2Ray (不走隧道):</b><br>
            使用服务器公网 IP | 路径: <code>${VMESS_WSPATH}</code>
        </div>
    </div>
</body>
</html>
EOF
    echo "=================================================="
    echo "X-Tunnel 域名: $DOMAIN_XT"
    echo "=================================================="
else
    echo "错误: 未能获取到域名，请检查 cf_xt.log"
    echo "Cloudflare Tunnel 可能启动失败或连接超时" > /usr/share/nginx/html/index.html
fi

# 8. 启动 V2Ray 前台运行
# 确保在启动前解码最新的配置
base64 -d config > temp_config.json
sed -i "s#UUID#$UUID#g;s#VMESS_WSPATH#${VMESS_WSPATH}#g;s#VLESS_WSPATH#${VLESS_WSPATH}#g" temp_config.json

echo "启动 V2Ray 主进程..."
./${RELEASE_RANDOMNESS} -config=temp_config.json
