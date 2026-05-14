#!/usr/bin/env bash

# 0. 配置双栈 DNS 并设置 IPv6 优先
echo "正在配置 DNS 并强制 IPv6 优先..."
cat > /etc/resolv.conf <<EOF
nameserver 169.254.254.254
nameserver 2001:4860:4860::8888
nameserver 2606:4700:4700::1111
nameserver 8.8.8.8
nameserver 1.1.1.1
options timeout:2 attempts:3 rotate
EOF

cat > /etc/gai.conf <<EOF
precedence  ::1/128       50
precedence  ::/0          40
precedence  ::ffff:0:0/96  10
EOF

# 1. 变量准备
UUID=${UUID:-'de04add9-5c68-8bab-950c-08cd5320df18'}
V1_PATH=${V1_PATH:-'/vmess'}
V2_PATH=${V2_PATH:-'/vless'}      # 路径名也顺便改得好记一点
V3_PATH=${V3_PATH:-'/vlesspacket'}
DOMAIN=${KOYEB_PUBLIC_DOMAIN:-"$(curl -s http://169.254.254.254/latest/meta-data/instance/attributes/public_hostname || echo 'your-domain.koyeb.app')"}

# 2. 生成 Xray 配置文件 (将 V2 改为 WebSocket 协议)
echo 'ewogICJsb2ciOiB7ICJhY2Nlc3MiOiAiL2Rldi9udWxsIiwgImVycm9yIjogIi9kZXYvbnVsbCIsICJsb2dsZXZlbCI6ICJ3YXJuaW5nIiB9LAogICJpbmJvdW5kcyI6IFsKICAgIHsgInBvcnQiOiAxMDAwMCwgImxpc3RlbiI6ICIxMjcuMC4wLjEiLCAicHJvdG9jb2wiOiAidm1lc3MiLCAic2V0dGluZ3MiOiB7ICJjbGllbnRzIjogWyB7ICJpZCI6ICJVVUlEX1ZBTCIgfSBdIH0sICJzdHJlYW1TZXR0aW5ncyI6IHsgIm5ldHdvcmsiOiAid3MiLCAid3NTZXR0aW5ncyI6IHsgInBhdGgiOiAiUEFUSDEiIH0gfSB9LAogICAgeyAicG9ydCI6IDIwMDAwLCAibGlzdGVuIjogIjEyNy4wLjAuMSIsICJwcm90b2NvbCI6ICJ2bGVzcyIsICJzZXR0aW5ncyI6IHsgImNsaWVudHMiOiBbIHsgImlkIjogIlVVSURfVkFMIiB9IF0sICJkZWNyeXB0aW9uIjogIm5vbmUiIH0sICJzdHJlYW1TZXR0aW5ncyI6IHsgIm5ldHdvcmsiOiAid3MiLCAid3NTZXR0aW5ncyI6IHsgInBhdGgiOiAiUEFUSDIiIH0gfSB9LAogICAgeyAicG9ydCI6IDMwMDAwLCAibGlzdGVuIjogIjEyNy4wLjAuMSIsICJwcm90b2NvbCI6ICJ2bGVzcyIsICJzZXR0aW5ncyI6IHsgImNsaWVudHMiOiBbIHsgImlkIjogIlVVSURfVkFMIiB9IF0sICJkZWNyeXB0aW9uIjogIm5vbmUiIH0sICJzdHJlYW1TZXR0aW5ncyI6IHsgIm5ldHdvcmsiOiAieGh0dHAiLCAieGh0dHBTZXR0aW5ncyI6IHsgInBhdGgiOiAiUEFUSDMiIH0gfSB9CiAgXSwKICAib3V0Ym91bmRzIjogWyB7ICJwcm90b2NvbCI6ICJmcmVlZG9tIiwgInNldHRpbmdzIjogeyAiZG9tYWluU3RyYXRlZ3kiOiAiVXNlSVB2NiIgfSB9IF0KfQ==' | base64 -d > config.json
# 使用 sed 安全替换占位符
sed -i "s/UUID_VAL/$UUID/g" config.json
sed -i "s#PATH1#$V1_PATH#g" config.json
sed -i "s#PATH2#$V2_PATH#g" config.json
sed -i "s#PATH3#$V3_PATH#g" config.json

# 3. 构造节点链接 (V2 改为 vless+ws 格式)
ADDRESS="www.visa.com"
VMESS_LINK=$(printf '{"v":"2","ps":"Koyeb_VMess_Visa","add":"%s","port":"443","id":"%s","aid":"0","scy":"auto","net":"ws","type":"none","host":"%s","path":"%s","tls":"tls","sni":"%s"}' "$ADDRESS" "$UUID" "$DOMAIN" "$V1_PATH" "$DOMAIN")
VMESS_LINK="vmess://$(echo -n "$VMESS_LINK" | base64 | tr -d '\n')"

VLESS_WS="vless://$UUID@$ADDRESS:443?encryption=none&security=tls&sni=$DOMAIN&type=ws&host=$DOMAIN&path=$V2_PATH#Koyeb_VLESS_WS"
VLESS_PACKET="vless://$UUID@$ADDRESS:443?encryption=none&security=tls&sni=$DOMAIN&type=xhttp&host=$DOMAIN&path=$V3_PATH&mode=packet-up#Koyeb_VLESS_Packet"

SUB_CONTENT=$(printf "$VMESS_LINK\n$VLESS_WS\n$VLESS_PACKET" | base64 | tr -d '\n')
echo "$SUB_CONTENT" > /usr/share/nginx/html/sub

# 4. 生成旗舰版订阅页面及 Base64 订阅文件
mkdir -p /usr/share/nginx/html

# 生成客户端识别的 Base64 订阅文件
printf "$VMESS_LINK\n$VLESS_WS\n$VLESS_PACKET" | base64 | tr -d '\n' > /usr/share/nginx/html/sub

# 生成美化版 HTML 控制台
cat > /usr/share/nginx/html/info.html <<EOF
<!DOCTYPE html>
<html lang="zh-CN">
<head>
    <meta charset="UTF-8">
    <meta name="viewport" content="width=device-width, initial-scale=1.0">
    <title>Xray 控制台</title>
    <style>
        :root { --primary: #2563eb; --success: #22c55e; --bg: #0f172a; --card: rgba(30, 41, 59, 0.7); --accent: linear-gradient(135deg, #60a5fa, #a78bfa); }
        body { font-family: 'PingFang SC', system-ui, sans-serif; background: var(--bg); color: #f8fafc; margin: 0; padding: 20px; min-height: 100vh; display: flex; justify-content: center; }
        .container { width: 100%; max-width: 600px; }
        .header { text-align: center; margin-bottom: 30px; }
        .header h1 { font-size: 1.8rem; margin: 0; background: var(--accent); -webkit-background-clip: text; -webkit-text-fill-color: transparent; }
        .card { background: var(--card); backdrop-filter: blur(10px); border: 1px solid rgba(255,255,255,0.1); border-radius: 16px; padding: 20px; margin-bottom: 20px; }
        .sub-card { background: linear-gradient(135deg, #1e293b 0%, #0f172a 100%); border: 1px solid #3b82f6; }
        .node-info { display: flex; justify-content: space-between; align-items: center; margin-bottom: 15px; }
        .node-name { font-weight: 600; font-size: 1.1rem; color: #e2e8f0; }
        .node-type { font-size: 0.75rem; background: rgba(59, 130, 246, 0.2); color: #60a5fa; padding: 2px 10px; border-radius: 20px; border: 1px solid rgba(59, 130, 246, 0.3); }
        .btn-group { display: grid; grid-template-columns: 1fr 1fr; gap: 10px; }
        .btn-single { grid-template-columns: 1fr; }
        button { border: none; padding: 12px; border-radius: 8px; cursor: pointer; font-weight: 600; transition: all 0.2s; font-size: 0.9rem; }
        .btn-copy { background: #334155; color: white; }
        .btn-copy:hover { background: #475569; }
        .btn-qr { background: var(--primary); color: white; }
        .btn-qr:hover { background: #1d4ed8; }
        .sub-url { font-size: 0.8rem; color: #94a3b8; background: rgba(0,0,0,0.3); padding: 10px; border-radius: 6px; margin-top: 10px; word-break: break-all; border: 1px solid rgba(255,255,255,0.05); }
        #qr-modal { display: none; position: fixed; inset: 0; background: rgba(0,0,0,0.8); z-index: 100; justify-content: center; align-items: center; flex-direction: column; }
        .qr-content { background: white; padding: 20px; border-radius: 12px; text-align: center; }
        .qr-content img { width: 200px; height: 200px; margin-bottom: 10px; }
        .close-btn { margin-top: 15px; color: #94a3b8; cursor: pointer; }
    </style>
</head>
<body>
    <div class="container">
        <div class="header"><h1>Xray 节点管理后台</h1><p style="color:#94a3b8">Koyeb 自动更新订阅系统</p></div>
        <div class="card sub-card">
            <div class="node-info"><span class="node-name" style="color:#60a5fa">自动订阅链接</span><span class="node-type" style="background:#1d4ed8; color:white">V2Ray / v2rayN</span></div>
            <div class="btn-group btn-single">
                <button class="btn-qr" onclick="copySub()">一键复制订阅地址</button>
            </div>
            <div class="sub-url" id="sub-display">加载中...</div>
        </div>
        <div class="card">
            <div class="node-info"><span class="node-name">VMess WebSocket</span><span class="node-type">Port: 443</span></div>
            <div class="btn-group">
                <button class="btn-copy" onclick="copy('$VMESS_LINK')">复制链接</button>
                <button class="btn-qr" onclick="showQR('$VMESS_LINK', 'VMess WS')">二维码</button>
            </div>
        </div>

        <div class="card">
            <div class="node-info"><span class="node-name">VLESS WebSocket</span><span class="node-type">V2 端口</span></div>
            <div class="btn-group">
                <button class="btn-copy" onclick="copy('$VLESS_WS')">复制链接</button>
                <button class="btn-qr" onclick="showQR('$VLESS_WS', 'VLESS WS')">二维码</button>
            </div>
        </div>
        <div class="card">
            <div class="node-info"><span class="node-name">VLESS Packet</span><span class="node-type">XHTTP</span></div>
            <div class="btn-group">
                <button class="btn-copy" onclick="copy('$VLESS_PACKET')">复制链接</button>
                <button class="btn-qr" onclick="showQR('$VLESS_PACKET', 'VLESS Packet')">二维码</button>
            </div>
        </div>
        <div style="text-align:center; font-size:0.8rem; color:#64748b; margin-top:20px;">
            优选地址: $ADDRESS | 节点 ID: ${UUID:0:8}...
        </div>
    </div>
    <div id="qr-modal" onclick="this.style.display='none'">
        <div class="qr-content" onclick="event.stopPropagation()">
            <h3 id="qr-title" style="color:#333; margin-top:0"></h3>
            <img id="qr-img" src="" alt="二维码">
            <div class="close-btn">点击空白处关闭</div>
        </div>
    </div>
    <script>
        // 获取当前订阅路径
        const subPath = "/${UUID}/sub";
        const fullSubUrl = window.location.origin + subPath;
        document.getElementById('sub-display').innerText = fullSubUrl;
        function copy(text) {
            const el = document.createElement('textarea');
            el.value = text; document.body.appendChild(el);
            el.select(); document.execCommand('copy');
            document.body.removeChild(el);
            alert('复制成功！');
        }
        function copySub() {
            copy(fullSubUrl);
            alert('订阅地址已复制！\n请到 v2rayN -> 订阅设置 中添加。');
        }
        function showQR(text, title) {
            document.getElementById('qr-title').innerText = title;
            document.getElementById('qr-img').src = 'https://quickchart.io/qr?size=250&text=' + encodeURIComponent(text);
            document.getElementById('qr-modal').style.display = 'flex';
        }
    </script>
</body>
</html>
EOF

# 5. 修改 Nginx (针对 V2_PATH 增加 WebSocket 转发头)
if [ -f /etc/nginx/nginx.conf ]; then
    sed -i "s#V1_PATH#${V1_PATH}#g;s#V2_PATH#${V2_PATH}#g;s#V3_PATH#${V3_PATH}#g" /etc/nginx/nginx.conf
    # 为 V2_PATH 添加 WebSocket 必要的 Upgrade 头部
    sed -i "/location ${V2_PATH} {/a \            proxy_http_version 1.1;\n            proxy_set_header Upgrade \$http_upgrade;\n            proxy_set_header Connection \"upgrade\";" /etc/nginx/nginx.conf

    sed -i "/location \/ {/i \        location /${UUID} {\n            alias /usr/share/nginx/html/;\n            index info.html;\n        }" /etc/nginx/nginx.conf
fi

# 6. 伪装启动
RELEASE_RANDOMNESS=$(tr -dc 'A-Za-z0-9' </dev/urandom | head -c 6)
mv v ${RELEASE_RANDOMNESS}

# 7. 安装/启动 哪吒探针
#[ -n "${NEZHA_SERVER}" ] && [ -n "${NEZHA_PORT}" ] && [ -n "${NEZHA_KEY}" ] && wget https://raw.githubusercontent.com/naiba/nezha/master/script/install.sh -O nezha.sh && chmod +x nezha.sh && echo '0' | ./nezha.sh install_agent ${NEZHA_SERVER} ${NEZHA_PORT} ${NEZHA_KEY}

[ -n "${NEZHA_SERVER}" ] && [ -n "${NEZHA_PORT}" ] && [ -n "${NEZHA_KEY}" ] && wget https://raw.githubusercontent.com/naiba/nezha/master/script/install.sh -O nezha.sh && chmod +x nezha.sh && echo '0' | ./nezha.sh install_agent ${NEZHA_SERVER} ${NEZHA_PORT} ${NEZHA_KEY} --tls

# 8. 启动 Nginx (后台运行)

nginx

# 9. 启动 Xray (前台运行，保持容器不退出)
echo "Xray 正在启动..."
./${RELEASE_RANDOMNESS} run -c config.json
