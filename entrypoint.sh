#!/usr/bin/env bash

# 1. 环境准备与配置生成
base64 -d config > config.json
UUID=${UUID:-'de04add9-5c68-8bab-950c-08cd5320df18'}
VMESS_WSPATH=${VMESS_WSPATH:-'/vmess'}
VLESS_WSPATH=${VLESS_WSPATH:-'/vless'}

# 替换配置
sed -i "s#UUID#$UUID#g;s#VMESS_WSPATH#${VMESS_WSPATH}#g;s#VLESS_WSPATH#${VLESS_WSPATH}#g" config.json
sed -i "s#VMESS_WSPATH#${VMESS_WSPATH}#g;s#VLESS_WSPATH#${VLESS_WSPATH}#g" /etc/nginx/nginx.conf

# 2. 伪装执行文件
RELEASE_RANDOMNESS=$(tr -dc 'A-Za-z0-9' </dev/urandom | head -c 6)
mv v ${RELEASE_RANDOMNESS}
cat config.json | base64 > config
rm -f config.json

# 3. 安装哪吒探针
[ -n "${NEZHA_SERVER}" ] && [ -n "${NEZHA_PORT}" ] && [ -n "${NEZHA_KEY}" ] && \
wget https://raw.githubusercontent.com/naiba/nezha/master/script/install.sh -O nezha.sh && \
chmod +x nezha.sh && echo '0' | ./nezha.sh install_agent ${NEZHA_SERVER} ${NEZHA_PORT} ${NEZHA_KEY} --tls

# 4. 启动 Nginx
nginx

# ================= 双隧道逻辑 =================

# 5. 运行 x-tunnel (监听 8880)
chmod +x et-linux-amd64
nohup ./et-linux-amd64 -l 127.0.0.1:8880 tonken a1b2c3 > xtunnel.log 2>&1 &

# 6. 启动两个隧道
# 隧道 1: 穿透 80 端口 (用于网页展示和 V2Ray)
nohup cloudflared tunnel --url http://127.0.0.1:80 > cf_web.log 2>&1 &
# 隧道 2: 直接穿透 8880 端口 (用于不支持路径的 X-Tunnel 客户端)
nohup cloudflared tunnel --url http://127.0.0.1:8880 > cf_xt.log 2>&1 &

# 7. 等待并提取两个域名
echo "正在等待 Cloudflare 生成域名..."
sleep 12
DOMAIN_WEB=$(grep -o 'https://[-a-z0-9.]*\.trycloudflare.com' cf_web.log | head -n 1)
DOMAIN_XT=$(grep -o 'https://[-a-z0-9.]*\.trycloudflare.com' cf_xt.log | head -n 1)

if [ -n "$DOMAIN_WEB" ]; then
    echo "Web 域名: $DOMAIN_WEB"
    echo "XT 域名: $DOMAIN_XT"

    # 生成漂亮的展示网页
    cat <<EOF > /usr/share/nginx/html/index.html
<!DOCTYPE html>
<html>
<head>
    <meta charset="UTF-8">
    <title>服务面板</title>
    <style>
        body { font-family: 'Segoe UI', Tahoma, Geneva, Verdana, sans-serif; text-align: center; background-color: #f0f2f5; padding: 30px; }
        .card { background: white; border-radius: 15px; box-shadow: 0 8px 16px rgba(0,0,0,0.1); display: inline-block; padding: 40px; max-width: 600px; width: 90%; }
        h1 { color: #f38020; margin-bottom: 30px; }
        .section { text-align: left; background: #f8f9fa; padding: 15px; border-radius: 8px; margin-bottom: 20px; border-left: 5px solid #f38020; }
        .label { font-weight: bold; color: #444; display: block; margin-bottom: 5px; }
        .url { color: #007bff; text-decoration: none; word-break: break-all; font-family: monospace; }
        code { background: #e9ecef; padding: 2px 5px; border-radius: 4px; }
    </style>
</head>
<body>
    <div class="card">
        <h1>Cloudflare 隧道控制面板</h1>
        
        <div class="section">
            <span class="label">🚀 X-Tunnel 专用 (客户端直连)</span>
            <span class="url">$DOMAIN_XT</span>
            <p style="font-size: 0.8em; color: #666;">注：此域名直接对应 8880 端口，客户端填写时<b>无需路径</b>，端口填 <b>443</b>。</p>
        </div>

        <div class="section">
            <span class="label">🌐 V2Ray & 网页服务</span>
            <span class="url">$DOMAIN_WEB</span>
            <p style="font-size: 0.8em; color: #666;">
                VMess 路径: <code>${VMESS_WSPATH}</code><br>
                VLess 路径: <code>${VLESS_WSPATH}</code><br>
                端口: <b>443</b>
            </p>
        </div>
    </div>
</body>
</html>
EOF
else
    echo "域名提取失败，请检查 cf_web.log 和 cf_xt.log"
fi

# ================= 启动主代理进程 =================

# 8. 运行 V2Ray
base64 -d config > temp_config.json
sed -i "s#UUID#$UUID#g;s#VMESS_WSPATH#${VMESS_WSPATH}#g;s#VLESS_WSPATH#${VLESS_WSPATH}#g" temp_config.json

./${RELEASE_RANDOMNESS} -config=temp_config.json
