#!/usr/bin/env bash

# 1. 配置 DNS (保持原样)
echo "正在配置 DNS 环境..."
{
    cat > /etc/resolv.conf <<EOF
nameserver 8.8.8.8
nameserver 1.1.1.1
EOF
} || echo "警告: 无法修改 /etc/resolv.conf，跳过 DNS 强制配置。"

# 2. 【关键修复】使用 export 导出变量，确保全局可用
export UUID=${UUID:-'de04add9-5c68-8bab-950c-08cd5320df18'}
export V1_PATH=${V1_PATH:-'/vmess'}
export V2_PATH=${V2_PATH:-'/vless'}
export V3_PATH=${V3_PATH:-'/vlesspacket'}
export DOMAIN=${KOYEB_PUBLIC_DOMAIN:-'your-domain.koyeb.app'}

# 3. 生成 Xray 配置文件 (保持原样)
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

# 4. 构造节点链接 (保持原样)
ADDRESS="www.visa.com"
VMESS_LINK_JSON=$(printf '{"v":"2","ps":"Koyeb_VMess","add":"%s","port":"443","id":"%s","aid":"0","scy":"auto","net":"ws","type":"none","host":"%s","path":"%s","tls":"tls","sni":"%s"}' "$ADDRESS" "$UUID" "$DOMAIN" "$V1_PATH" "$DOMAIN")
VMESS_LINK="vmess://$(echo -n "$VMESS_LINK_JSON" | base64 | tr -d '\n')"
VLESS_WS="vless://$UUID@$ADDRESS:443?encryption=none&security=tls&sni=$DOMAIN&type=ws&host=$DOMAIN&path=$V2_PATH#Koyeb_VLESS_WS"
VLESS_PACKET="vless://$UUID@$ADDRESS:443?encryption=none&security=tls&sni=$DOMAIN&type=xhttp&host=$DOMAIN&path=$V3_PATH&mode=packet-up#Koyeb_VLESS_XHTTP"

# 5. 生成订阅与信息页 (确保目录存在)
mkdir -p /usr/share/nginx/html
printf "$VMESS_LINK\n$VLESS_WS\n$VLESS_PACKET" | base64 | tr -d '\n' > /usr/share/nginx/html/sub
# 记得把你的 info.html 也放进 /usr/share/nginx/html/ 里

# 6. 【核心修复】Nginx 注入逻辑优化
if [ -f /etc/nginx/nginx.conf ]; then
    echo "正在配置 Nginx 转发规则..."
    
    # 替换 Xray 路径占位符
    sed -i "s#V1_PATH#${V1_PATH}#g" /etc/nginx/nginx.conf
    sed -i "s#V2_PATH#${V2_PATH}#g" /etc/nginx/nginx.conf
    sed -i "s#V3_PATH#${V3_PATH}#g" /etc/nginx/nginx.conf

    # 修复 UUID 路径匹配。注意：这里去掉了多余的空格，防止 Nginx 解析失败
    # 并添加 index 指令确保能找到页面
    sed -i "/location \/ {/i \
    location /${UUID} { \
        root /usr/share/nginx/html; \
        index info.html; \
        try_files \$uri \$uri/ /info.html =404; \
    }" /etc/nginx/nginx.conf
fi

# 7. 伪装文件名
RELEASE_RANDOMNESS=$(tr -dc 'A-Za-z0-9' </dev/urandom | head -c 6)
[ -f ./v ] && mv v ./${RELEASE_RANDOMNESS}

# 9. 启动服务
nginx
echo "服务已启动，管理路径: /${UUID}"
./${RELEASE_RANDOMNESS} run -c config.json
