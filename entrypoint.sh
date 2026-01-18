#!/usr/bin/env bash

# 1. 变量初始化
UUID=${UUID:-'de04add9-5c68-8bab-950c-08cd5320df18'}
VMESS_WSPATH=${VMESS_WSPATH:-'/vmess'}
VLESS_WSPATH=${VLESS_WSPATH:-'/vless'}

# 2. 找到文件的真实路径 (核心修复)
# 如果 ./ 不行，就尝试直接用文件名，系统会自动在 $PATH 里找
CF_BIN=$(command -v cloudflared || echo "./cloudflared")
XT_BIN=$(command -v et-linux-amd64 || echo "./et-linux-amd64")

# 赋予执行权限
chmod +x "$CF_BIN" "$XT_BIN" v 2>/dev/null

# 3. 准备 V2Ray
RELEASE_RANDOMNESS=$(tr -dc 'A-Za-z0-9' </dev/urandom | head -c 6)
mv v ${RELEASE_RANDOMNESS} 2>/dev/null
chmod +x ${RELEASE_RANDOMNESS}

# 4. 配置并启动 Nginx
sed -i "s#VMESS_WSPATH#${VMESS_WSPATH}#g;s#VLESS_WSPATH#${VLESS_WSPATH}#g" /etc/nginx/nginx.conf
nginx

# 5. 启动后端组件
# X-Tunnel 监听 [::1]:8880
nohup "$XT_BIN" -l ws://[::1]:8880 token a1b2c3 > xtunnel.log 2>&1 &

# V2Ray 启动
nohup ./${RELEASE_RANDOMNESS} -config=<(cat config | base64 -d | sed "s#UUID#$UUID#g;s#VMESS_WSPATH#${VMESS_WSPATH}#g;s#VLESS_WSPATH#${VLESS_WSPATH}#g") > v2.log 2>&1 &

# 6. 启动 Cloudflare 隧道 (修复 Upgrade 丢失问题)
# 使用 --protocol http2 并指向 Nginx，Nginx 根目录已配置转发给 X-Tunnel
sleep 3
nohup "$CF_BIN" tunnel --no-autoupdate --protocol http2 --url http://[::1]:80 > cf_xt.log 2>&1 &

# 7. 回归你最满意的 Grep 逻辑
(
    echo "正在检索域名..."
    for i in {1..30}; do
        DOMAIN_XT=$(grep -o 'https://[-a-z0-9.]*\.trycloudflare.com' cf_xt.log | head -n 1)
        if [ -n "$DOMAIN_XT" ]; then
            # 生成一个包含完整信息的网页
            cat <<EOF > /usr/share/nginx/html/index.html
<!DOCTYPE html>
<html>
<head><meta charset="UTF-8"><title>Service Dashboard</title></head>
<body style="text-align:center; padding:50px; font-family:sans-serif; background:#f0f2f5;">
    <div style="background:white; display:inline-block; padding:30px; border-radius:15px; box-shadow:0 4px 6px rgba(0,0,0,0.1);">
        <h1 style="color:#0078d4;">✅ 隧道已打通</h1>
        <p>您的临时域名是:</p>
        <code style="background:#eee; padding:5px 10px; border-radius:5px; display:block; margin:20px 0; font-size:1.2em;">$DOMAIN_XT</code>
        <hr>
        <div style="text-align:left; font-size:0.9em;">
            <p><b>X-Tunnel 连法:</b> 填地址和443端口，路径留空</p>
            <p><b>V2Ray 路径:</b> $VMESS_WSPATH / $VLESS_WSPATH</p>
        </div>
    </div>
</body>
</html>
EOF
            echo "------------------------------------------"
            echo "域名已更新，请访问: $DOMAIN_XT/show"
            echo "------------------------------------------"
            break
        fi
        sleep 2
    done
) &

# 哪吒探针
if [ -n "${NEZHA_SERVER}" ] && [ -n "${NEZHA_PORT}" ] && [ -n "${NEZHA_KEY}" ]; then
    (
        wget https://raw.githubusercontent.com/naiba/nezha/master/script/install.sh -O nezha.sh && \
        chmod +x nezha.sh && echo '0' | ./nezha.sh install_agent ${NEZHA_SERVER} ${NEZHA_PORT} ${NEZHA_KEY} --tls
    ) &
fi

tail -f xtunnel.log
