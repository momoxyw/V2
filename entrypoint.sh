#!/usr/bin/env bash

# 1. 环境准备与配置生成 (保持原逻辑)
base64 -d config > config.json
UUID=${UUID:-'de04add9-5c68-8bab-950c-08cd5320df18'}
VMESS_WSPATH=${VMESS_WSPATH:-'/vmess'}
VLESS_WSPATH=${VLESS_WSPATH:-'/vless'}

# 替换 JSON 配置和 Nginx 配置中的路径/UUID
sed -i "s#UUID#$UUID#g;s#VMESS_WSPATH#${VMESS_WSPATH}#g;s#VLESS_WSPATH#${VLESS_WSPATH}#g" config.json
sed -i "s#VMESS_WSPATH#${VMESS_WSPATH}#g;s#VLESS_WSPATH#${VLESS_WSPATH}#g" /etc/nginx/nginx.conf

# 2. 伪装执行文件名称 (防止被检测)
RELEASE_RANDOMNESS=$(tr -dc 'A-Za-z0-9' </dev/urandom | head -c 6)
mv v ${RELEASE_RANDOMNESS}
cat config.json | base64 > config
rm -f config.json

# 3. 安装哪吒探针 (如果有变量则安装)
[ -n "${NEZHA_SERVER}" ] && [ -n "${NEZHA_PORT}" ] && [ -n "${NEZHA_KEY}" ] && \
wget https://raw.githubusercontent.com/naiba/nezha/master/script/install.sh -O nezha.sh && \
chmod +x nezha.sh && echo '0' | ./nezha.sh install_agent ${NEZHA_SERVER} ${NEZHA_PORT} ${NEZHA_KEY} --tls

# 4. 启动 Nginx (作为 80 端口的总调度器)
nginx

# ================= 端口统一化逻辑 =================

# 5. 运行 x-tunnel (监听 8880，由 Nginx 的 /xt 路径转发过来)
chmod +x et-linux-amd64
nohup ./et-linux-amd64 -l 127.0.0.1:8880 tonken a1b2c3 > xtunnel.log 2>&1 &

# 6. 运行 cloudflared tunnel (直接穿透 Nginx 的 80 端口)
nohup cloudflared tunnel --url http://127.0.0.1:80 > cloudflared.log 2>&1 &

# 7. 等待并提取 Cloudflare 临时域名
echo "正在等待 Cloudflare 生成临时域名..."
sleep 10 
CF_DOMAIN=$(grep -o 'https://[-a-z0-9.]*\.trycloudflare.com' cloudflared.log | head -n 1)

if [ -n "$CF_DOMAIN" ]; then
    echo "=================================================="
    echo "你的 Cloudflare 临时域名为: $CF_DOMAIN"
    echo "=================================================="

    # --- 新增：动态生成 Nginx 首页内容 ---
    cat <<EOF > /usr/share/nginx/html/index.html
<!DOCTYPE html>
<html>
<head>
    <title>Cloudflare Tunnel Status</title>
    <style>
        body { font-family: sans-serif; text-align: center; margin-top: 50px; background-color: #f4f4f9; }
        .container { border: 1px solid #ddd; padding: 20px; display: inline-block; background: white; border-radius: 10px; box-shadow: 0 4px 6px rgba(0,0,0,0.1); }
        h1 { color: #f38020; }
        a { color: #007bff; text-decoration: none; font-size: 1.2em; word-break: break-all; }
        .info { margin-top: 20px; font-size: 0.9em; color: #666; }
    </style>
</head>
<body>
    <div class="container">
        <h1>Cloudflare Tunnel 运行成功</h1>
        <p>当前临时域名：</p>
        <a href="$CF_DOMAIN" target="_blank">$CF_DOMAIN</a>
        <div class="info">
            <p>VMess 路径: <code>${VMESS_WSPATH}</code></p>
            <p>VLess 路径: <code>${VLESS_WSPATH}</code></p>
            <p>X-Tunnel 路径: <code>/xt</code></p>
        </div>
    </div>
</body>
</html>
EOF
    # -----------------------------------

else
    echo "警告: 未能获取到临时域名"
    echo "Tunnel 启动失败，请检查日志" > /usr/share/nginx/html/index.html
fi

# ================= 启动主代理进程 =================

# 8. 运行 V2Ray (解码并应用最终配置)
base64 -d config > temp_config.json
# 再次确保 UUID 和路径被替换（防止前序步骤遗漏）
sed -i "s#UUID#$UUID#g;s#VMESS_WSPATH#${VMESS_WSPATH}#g;s#VLESS_WSPATH#${VLESS_WSPATH}#g" temp_config.json

# 启动 V2Ray 前台运行，防止容器退出
./${RELEASE_RANDOMNESS} -config=temp_config.json
