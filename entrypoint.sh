#!/usr/bin/env bash

# 1. 变量初始化
UUID=${UUID:-'de04add9-5c68-8bab-950c-08cd5320df18'}
VMESS_WSPATH=${VMESS_WSPATH:-'/vmess'}
VLESS_WSPATH=${VLESS_WSPATH:-'/vless'}

# 2. 立即处理 V2Ray 配置与重命名 (确保启动最快)
RELEASE_RANDOMNESS=$(tr -dc 'A-Za-z0-9' </dev/urandom | head -c 6)
mv v ${RELEASE_RANDOMNESS}
base64 -d config > temp_config.json
sed -i "s#UUID#$UUID#g;s#VMESS_WSPATH#${VMESS_WSPATH}#g;s#VLESS_WSPATH#${VLESS_WSPATH}#g" temp_config.json

# 3. 立即配置 Nginx
sed -i "s#VMESS_WSPATH#${VMESS_WSPATH}#g;s#VLESS_WSPATH#${VLESS_WSPATH}#g" /etc/nginx/nginx.conf

# 4. 【关键】先启动所有业务服务，确保健康检查通过
# 启动 Nginx (端口 80)
nginx
# 启动 X-Tunnel (端口 8880)
chmod +x et-linux-amd64
nohup ./et-linux-amd64 -l 127.0.0.1:8880 token a1b2c3 > xtunnel.log 2>&1 &
# 启动 Cloudflare Tunnel
nohup cloudflared tunnel --url http://127.0.0.1:8880 > cf_xt.log 2>&1 &

# 5. 【后台运行】将耗时的哪吒探针安装放到后台，不阻塞启动流程
if [ -n "${NEZHA_SERVER}" ] && [ -n "${NEZHA_PORT}" ] && [ -n "${NEZHA_KEY}" ]; then
    (
        wget https://raw.githubusercontent.com/naiba/nezha/master/script/install.sh -O nezha.sh && \
        chmod +x nezha.sh && echo '0' | ./nezha.sh install_agent ${NEZHA_SERVER} ${NEZHA_PORT} ${NEZHA_KEY} --tls
    ) &
fi

# 6. 等待并提取域名
echo "正在等待 Cloudflare 生成域名..."
sleep 10
DOMAIN_XT=$(grep -o 'https://[-a-z0-9.]*\.trycloudflare.com' cf_xt.log | head -n 1)

if [ -n "$DOMAIN_XT" ]; then
    cat <<EOF > /usr/share/nginx/html/index.html
<!DOCTYPE html>
<html>
<head><meta charset="UTF-8"><title>Success</title></head>
<body style="text-align:center; padding:50px; font-family:sans-serif;">
    <h1 style="color:#333;">🚀 服务已启动</h1>
    <p>隧道地址: <b style="color:#f38020;">$DOMAIN_XT</b></p>
    <p style="font-size:0.8em; color:#666;">UUID: $UUID</p>
</body>
</html>
EOF
    echo "X-Tunnel Domain: $DOMAIN_XT"
fi

# 7. 启动 V2Ray 前台运行 (必须在最后)
echo "启动 V2Ray..."
./${RELEASE_RANDOMNESS} -config=temp_config.json
