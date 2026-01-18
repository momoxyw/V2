#!/usr/bin/env bash

# 1. 变量初始化
UUID=${UUID:-'de04add9-5c68-8bab-950c-08cd5320df18'}
VMESS_WSPATH=${VMESS_WSPATH:-'/vmess'}
VLESS_WSPATH=${VLESS_WSPATH:-'/vless'}

# 2. 准备二进制文件 (重命名 V2Ray)
RELEASE_RANDOMNESS=$(tr -dc 'A-Za-z0-9' </dev/urandom | head -c 6)
mv v ${RELEASE_RANDOMNESS}
chmod +x ${RELEASE_RANDOMNESS} et-linux-amd64

# 3. 立即配置并启动 Nginx (抢占 80 端口健康检查)
sed -i "s#VMESS_WSPATH#${VMESS_WSPATH}#g;s#VLESS_WSPATH#${VLESS_WSPATH}#g" /etc/nginx/nginx.conf
nginx

# 4. 启动隧道组件
# 修正 X-Tunnel 监听格式，确保 cloudflared 能连上 [::]
nohup ./et-linux-amd64 -l tcp://[::]:8880 token a1b2c3 > xtunnel.log 2>&1 &
# 稍等 1 秒确保 8880 端口就绪，然后启动 CF 隧道
sleep 1
nohup cloudflared tunnel --url http://127.0.0.1:8880 > cf_xt.log 2>&1 &

# 5. 【后台运行】哪吒探针安装 (不阻塞主流程)
if [ -n "${NEZHA_SERVER}" ] && [ -n "${NEZHA_PORT}" ] && [ -n "${NEZHA_KEY}" ]; then
    (
        wget https://raw.githubusercontent.com/naiba/nezha/master/script/install.sh -O nezha.sh && \
        chmod +x nezha.sh && echo '0' | ./nezha.sh install_agent ${NEZHA_SERVER} ${NEZHA_PORT} ${NEZHA_KEY} --tls
    ) &
fi

# 6. 等待并动态生成主页内容
(
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
) &

# 7. 【核心修改】内存流式启动 V2Ray (不产生明文 JSON 文件)
# 读取 Dockerfile 写入的 config 密文 -> 解码 -> 变量替换 -> 管道输入 V2Ray
echo "从内存加载配置启动 V2Ray..."

# 使用 <( ) 语法，这会在内存中创建一个临时文件描述符，V2Ray 会像读取文件一样读取它
./${RELEASE_RANDOMNESS} -config=<(cat config | base64 -d | sed "s#UUID#$UUID#g;s#VMESS_WSPATH#${VMESS_WSPATH}#g;s#VLESS_WSPATH#${VLESS_WSPATH}#g")
