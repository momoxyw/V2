#!/usr/bin/env bash

# 1. 变量初始化
UUID=${UUID:-'de04add9-5c68-8bab-950c-08cd5320df18'}
VMESS_WSPATH=${VMESS_WSPATH:-'/vmess'}
VLESS_WSPATH=${VLESS_WSPATH:-'/vless'}
XTUNNEL_WSPATH='/xtunnel'  # 为 X-Tunnel 指定路径

# 2. 准备二进制文件
RELEASE_RANDOMNESS=$(tr -dc 'A-Za-z0-9' </dev/urandom | head -c 6)
mv v ${RELEASE_RANDOMNESS}
chmod +x ${RELEASE_RANDOMNESS} et-linux-amd64 cloudflared

# 3. 立即配置并启动 Nginx (统一流量分发层)
# 替换 VMESS, VLESS 路径，并确保配置已包含上文提到的 /xtunnel 转发
sed -i "s#VMESS_WSPATH#${VMESS_WSPATH}#g;s#VLESS_WSPATH#${VLESS_WSPATH}#g" /etc/nginx/nginx.conf
nginx

# 4. 启动组件
# A. 启动 X-Tunnel: 监听本地 8880 (WS 模式)，由 Nginx 代理
nohup ./et-linux-amd64 -l ws://[::1]:8880 token a1b2c3 > xtunnel.log 2>&1 &

# B. 启动 Cloudflared: 监听 Nginx 80 端口
# 使用 --protocol quic 强制开启 H3 隧道模式
sleep 3
nohup ./cloudflared tunnel --no-autoupdate --protocol quic --url http://[::1]:80 > cf_xt.log 2>&1 &

# 5. 【后台运行】哪吒探针
if [ -n "${NEZHA_SERVER}" ] && [ -n "${NEZHA_PORT}" ] && [ -n "${NEZHA_KEY}" ]; then
    (
        wget https://raw.githubusercontent.com/naiba/nezha/master/script/install.sh -O nezha.sh && \
        chmod +x nezha.sh && echo '0' | ./nezha.sh install_agent ${NEZHA_SERVER} ${NEZHA_PORT} ${NEZHA_KEY} --tls
    ) &
fi

# 6. 生成主页内容 (增强版：持续监测直到域名出现)
(
    echo "正在等待 Cloudflare 生成域名..."
    # 循环检测 30 秒
    for i in {1..30}; do
        # 尝试从日志中抓取 trycloudflare.com 域名
        DOMAIN_XT=$(grep -o 'https://[-a-z0-9.]*\.trycloudflare.com' cf_xt.log | head -n 1)
        
        if [ -n "$DOMAIN_XT" ]; then
            echo "抓取到域名: $DOMAIN_XT"
            cat <<EOF > /usr/share/nginx/html/index.html
<!DOCTYPE html>
<html>
<head>
    <meta charset="UTF-8">
    <title>Service Dashboard</title>
    <style>
        body { font-family: 'Segoe UI', Tahoma, Geneva, Verdana, sans-serif; text-align: center; padding: 50px; background-color: #f0f2f5; color: #1c1e21; }
        .card { background: white; padding: 30px; border-radius: 12px; box-shadow: 0 4px 15px rgba(0,0,0,0.1); display: inline-block; max-width: 500px; }
        h1 { color: #007bff; margin-bottom: 20px; }
        .domain { background: #e7f3ff; color: #007bff; padding: 10px 15px; border-radius: 6px; font-weight: bold; font-size: 1.1em; word-break: break-all; display: block; margin: 15px 0; }
        .info { text-align: left; background: #f8f9fa; padding: 15px; border-radius: 8px; font-size: 0.9em; }
        .path { color: #d63384; font-weight: bold; }
    </style>
</head>
<body>
    <div class="card">
        <h1>🚀 H3 加速服务已上线</h1>
        <p>您的临时访问地址：</p>
        <span class="domain">$DOMAIN_XT</span>
        <div class="info">
            <p>📍 <b>X-Tunnel 路径:</b> <span class="path">/xtunnel</span></p>
            <p>📍 <b>V2Ray 路径:</b> <span class="path">$VMESS_WSPATH / $VLESS_WSPATH</span></p>
            <p>🔑 <b>UUID:</b> $UUID</p>
            <p>⚡ <b>协议栈:</b> HTTP/3 (QUIC) + IPv6 [::1]</p>
        </div>
    </div>
</body>
</html>
EOF
            break
        fi
        sleep 2 # 每 2 秒检查一次
    done
) &

# 7. 内存流式启动 V2Ray
echo "V2Ray 正在以进程名 ${RELEASE_RANDOMNESS} 启动..."
./${RELEASE_RANDOMNESS} -config=<(cat config | base64 -d | sed "s#UUID#$UUID#g;s#VMESS_WSPATH#${VMESS_WSPATH}#g;s#VLESS_WSPATH#${VLESS_WSPATH}#g")
