#!/usr/bin/env bash

# 1. 配置 DNS (增加内存限制变量)
echo "正在配置环境..."
export GOMEMLIMIT=160MiB  # 给 Nginx 留出空间，防止 Xray 吃光内存
{
    echo -e "nameserver 8.8.8.8\nnameserver 1.1.1.1" > /etc/resolv.conf
} || echo "警告: 无法修改 DNS 配置，跳过。"

# 2. 导出变量
export UUID=${UUID:-'de04add9-5c68-8bab-950c-08cd5320df18'}
export V1_PATH=${V1_PATH:-'/vmess'}
export V2_PATH=${V2_PATH:-'/vless'}
export V3_PATH=${V3_PATH:-'/vlesspacket'}
export DOMAIN=${KOYEB_PUBLIC_DOMAIN:-'your-domain.koyeb.app'}

# 3. 生成 Xray 配置文件 (极致精简版)
cat > config.json <<EOF
{
  "log": { "access": "/dev/null", "error": "/dev/null", "loglevel": "none" },
  "inbounds": [
    { "port": 10000, "listen": "127.0.0.1", "protocol": "vmess", "settings": { "clients": [ { "id": "$UUID" } ] }, "streamSettings": { "network": "ws", "wsSettings": { "path": "$V1_PATH" } } },
    { "port": 20000, "listen": "127.0.0.1", "protocol": "vless", "settings": { "clients": [ { "id": "$UUID" } ], "decryption": "none" }, "streamSettings": { "network": "ws", "wsSettings": { "path": "$V2_PATH" } } },
    { "port": 30000, "listen": "127.0.0.1", "protocol": "vless", "settings": { "clients": [ { "id": "$UUID" } ], "decryption": "none" }, "streamSettings": { "network": "xhttp", "xhttpSettings": { "path": "$V3_PATH", "mode": "packet-up" } } }
  ],
  "outbounds": [ { "protocol": "freedom", "settings": { "domainStrategy": "UseIPv4" } } ]
}
EOF

# 4. 构造节点链接
ADDRESS="www.visa.com"
VMESS_LINK_JSON=$(printf '{"v":"2","ps":"Koyeb_VMess","add":"%s","port":"443","id":"%s","aid":"0","scy":"auto","net":"ws","type":"none","host":"%s","path":"%s","tls":"tls","sni":"%s"}' "$ADDRESS" "$UUID" "$DOMAIN" "$V1_PATH" "$DOMAIN")
VMESS_LINK="vmess://$(echo -n "$VMESS_LINK_JSON" | base64 | tr -d '\n')"
VLESS_WS="vless://$UUID@$ADDRESS:443?encryption=none&security=tls&sni=$DOMAIN&type=ws&host=$DOMAIN&path=$V2_PATH#Koyeb_VLESS_WS"
VLESS_PACKET="vless://$UUID@$ADDRESS:443?encryption=none&security=tls&sni=$DOMAIN&type=xhttp&host=$DOMAIN&path=$V3_PATH&mode=packet-up#Koyeb_VLESS_XHTTP"

# 5. 生成订阅
mkdir -p /usr/share/nginx/html
printf "$VMESS_LINK\n$VLESS_WS\n$VLESS_PACKET" | base64 | tr -d '\n' > /usr/share/nginx/html/sub

# 6. 修改 Nginx 配置
if [ -f /etc/nginx/nginx.conf ]; then
    echo "正在同步 Nginx 转发规则..."
    sed -i "s#UUID_PATH#${UUID}#g" /etc/nginx/nginx.conf
    sed -i "s#V1_PATH#${V1_PATH}#g" /etc/nginx/nginx.conf
    sed -i "s#V2_PATH#${V2_PATH}#g" /etc/nginx/nginx.conf
    sed -i "s#V3_PATH#${V3_PATH}#g" /etc/nginx/nginx.conf
fi

# 7. 伪装文件名并启动
RELEASE_RANDOMNESS=$(tr -dc 'A-Za-z0-9' </dev/urandom | head -c 6)
if [ -f ./v ]; then
    mv v ./${RELEASE_RANDOMNESS}
elif [ ! -f ./${RELEASE_RANDOMNESS} ]; then
    # 如果已经重命名过了，寻找当前目录下的可执行文件
    CURRENT_V=$(find . -maxdepth 1 -type f -executable -name "[A-Za-z0-9]*" | head -n 1)
    if [ -z "$CURRENT_V" ]; then echo "错误: 未找到核心文件"; exit 1; fi
    RELEASE_RANDOMNESS=${CURRENT_V#./}
fi

# 8. 启动服务
pkill -9 nginx || true
nginx
echo "服务已启动，管理路径: /${UUID}"

# 启动核心进程 (使用 nohup 配合日志清理)
chmod +x ./${RELEASE_RANDOMNESS}
./${RELEASE_RANDOMNESS} run -c config.json
