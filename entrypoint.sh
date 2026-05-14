#!/usr/bin/env bash

# 1. 尝试配置 DNS (针对 Read-only 做了容错)
echo "正在配置 DNS 环境..."
{
    echo -e "nameserver 8.8.8.8\nnameserver 1.1.1.1" > /etc/resolv.conf
} || echo "警告: 无法修改 /etc/resolv.conf，跳过 DNS 强制配置。"

# 2. 导出变量，确保全局可用
export UUID=${UUID:-'de04add9-5c68-8bab-950c-08cd5320df18'}
export V1_PATH=${V1_PATH:-'/vmess'}
export V2_PATH=${V2_PATH:-'/vless'}
export V3_PATH=${V3_PATH:-'/vlesspacket'}
export DOMAIN=${KOYEB_PUBLIC_DOMAIN:-'your-domain.koyeb.app'}

# 3. 生成 Xray 配置文件
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

# 5. 生成订阅与信息页
mkdir -p /usr/share/nginx/html
printf "$VMESS_LINK\n$VLESS_WS\n$VLESS_PACKET" | base64 | tr -d '\n' > /usr/share/nginx/html/sub

# 6. 修改 Nginx 配置 (适配新的模板)
if [ -f /etc/nginx/nginx.conf ]; then
    echo "正在配置 Nginx 转发规则..."
    
    # 1. 替换 UUID 管理路径 (注意这里不再用注入，而是替换模板里的占位符)
    # 我们把模板里的 UUID_PATH 替换为真实的 UUID
    sed -i "s#UUID_PATH#${UUID}#g" /etc/nginx/nginx.conf

    # 2. 替换节点路径占位符
    sed -i "s#V1_PATH#${V1_PATH}#g" /etc/nginx/nginx.conf
    sed -i "s#V2_PATH#${V2_PATH}#g" /etc/nginx/nginx.conf
    sed -i "s#V3_PATH#${V3_PATH}#g" /etc/nginx/nginx.conf
    
    echo "Nginx 配置替换完成。"
fi

# 7. 伪装文件名 (确保文件名随机且移动成功)
RELEASE_RANDOMNESS=$(tr -dc 'A-Za-z0-9' </dev/urandom | head -c 6)
if [ -f ./v ]; then
    mv v ./${RELEASE_RANDOMNESS}
else
    # 如果找不到名为 v 的执行文件，尝试寻找其他可执行文件或直接报错
    echo "错误: 未找到核心执行文件 v"
    exit 1
fi

# 8. 启动服务
nginx
echo "服务已启动，管理路径: /${UUID}"
echo "订阅链接已生成至 /usr/share/nginx/html/sub"

# 启动核心进程
./${RELEASE_RANDOMNESS} run -c config.json
