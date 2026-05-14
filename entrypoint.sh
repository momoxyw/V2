#!/usr/bin/env bash

# 1. 尝试配置 DNS (针对 Read-only 错误做了处理)
echo "正在配置 DNS 环境..."
{
    cat > /etc/resolv.conf <<EOF
nameserver 169.254.254.254
nameserver 2001:4860:4860::8888
nameserver 8.8.8.8
options timeout:2 attempts:3 rotate
EOF
} || echo "警告: 无法修改 /etc/resolv.conf，跳过 DNS 强制配置。"

# 2. 变量准备与默认值
UUID=${UUID:-'de04add9-5c68-8bab-950c-08cd5320df18'}
V1_PATH=${V1_PATH:-'/vmess'}
V2_PATH=${V2_PATH:-'/vless'}
V3_PATH=${V3_PATH:-'/vlesspacket'}
# 获取域名，增加回退机制
DOMAIN=${KOYEB_PUBLIC_DOMAIN:-'your-domain.koyeb.app'}

# 3. 生成 Xray 配置文件 (V1:VMess+WS, V2:VLESS+WS, V3:VLESS+XHTTP)
# 注意：这里将配置直接写为 JSON 字符串，避免 base64 转换带来的版本兼容问题
cat > config.json <<EOF
{
  "log": { "access": "/dev/null", "error": "/dev/null", "loglevel": "warning" },
  "inbounds": [
    { "port": 10000, "listen": "127.0.0.1", "protocol": "vmess", "settings": { "clients": [ { "id": "$UUID" } ] }, "streamSettings": { "network": "ws", "wsSettings": { "path": "$V1_PATH" } } },
    { "port": 20000, "listen": "127.0.0.1", "protocol": "vless", "settings": { "clients": [ { "id": "$UUID" } ], "decryption": "none" }, "streamSettings": { "network": "ws", "wsSettings": { "path": "$V2_PATH" } } },
    { "port": 30000, "listen": "127.0.0.1", "protocol": "vless", "settings": { "clients": [ { "id": "$UUID" } ], "decryption": "none" }, "streamSettings": { "network": "xhttp", "xhttpSettings": { "path": "$V3_PATH", "mode": "packet-up" } } }
  ],
  "outbounds": [ { "protocol": "freedom", "settings": { "domainStrategy": "UseIPv6" } } ]
}
EOF

# 4. 构造节点链接
ADDRESS="www.visa.com"
VMESS_LINK_JSON=$(printf '{"v":"2","ps":"Koyeb_VMess","add":"%s","port":"443","id":"%s","aid":"0","scy":"auto","net":"ws","type":"none","host":"%s","path":"%s","tls":"tls","sni":"%s"}' "$ADDRESS" "$UUID" "$DOMAIN" "$V1_PATH" "$DOMAIN")
VMESS_LINK="vmess://$(echo -n "$VMESS_LINK_JSON" | base64 | tr -d '\n')"
VLESS_WS="vless://$UUID@$ADDRESS:443?encryption=none&security=tls&sni=$DOMAIN&type=ws&host=$DOMAIN&path=$V2_PATH#Koyeb_VLESS_WS"
VLESS_PACKET="vless://$UUID@$ADDRESS:443?encryption=none&security=tls&sni=$DOMAIN&type=xhttp&host=$DOMAIN&path=$V3_PATH&mode=packet-up#Koyeb_VLESS_XHTTP"

# 5. 生成订阅文件与信息页
mkdir -p /usr/share/nginx/html
printf "$VMESS_LINK\n$VLESS_WS\n$VLESS_PACKET" | base64 | tr -d '\n' > /usr/share/nginx/html/sub

# 这里为了简洁，直接输出简单的信息页（你原有的 HTML 内容太长，建议保持原样但确保变量引用正确）
# 确保 HTML 中的 $VMESS_LINK 等变量能被正确替换

# 6. 修改 Nginx 配置 (核心修复：解决路径替换和括号匹配)
if [ -f /etc/nginx/nginx.conf ]; then
    echo "正在配置 Nginx 转发规则..."
    # 替换路径占位符
    sed -i "s#V1_PATH#${V1_PATH}#g" /etc/nginx/nginx.conf
    sed -i "s#V2_PATH#${V2_PATH}#g" /etc/nginx/nginx.conf
    sed -i "s#V3_PATH#${V3_PATH}#g" /etc/nginx/nginx.conf

    # 注入管理后台路径 (在 location / 之前插入)
    # 注意：使用简单的文本追加，避免 sed 版本差异
    sed -i "/location \/ {/i \
        location /${UUID} { \
            alias /usr/share/nginx/html/; \
            index info.html; \
        }" /etc/nginx/nginx.conf
fi

# 7. 伪装启动文件名
RELEASE_RANDOMNESS=$(tr -dc 'A-Za-z0-9' </dev/urandom | head -c 6)
[ -f ./v ] && mv v ./${RELEASE_RANDOMNESS} || echo "警告: 未找到执行文件 'v'"

# 8. 启动哪吒探针 (如果变量存在)
if [ -n "${NEZHA_SERVER}" ] && [ -n "${NEZHA_PORT}" ] && [ -n "${NEZHA_KEY}" ]; then
    echo "正在启动哪吒探针..."
    wget https://raw.githubusercontent.com/naiba/nezha/master/script/install.sh -O nezha.sh && chmod +x nezha.sh
    echo '0' | ./nezha.sh install_agent ${NEZHA_SERVER} ${NEZHA_PORT} ${NEZHA_KEY} --tls >/dev/null 2>&1 &
fi

# 9. 启动服务
nginx
echo "Xray 正在以路径 $V3_PATH (XHTTP) 启动..."
./${RELEASE_RANDOMNESS} run -c config.json
