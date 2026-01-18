#!/usr/bin/env bash

# 1. 变量初始化
UUID=${UUID:-'de04add9-5c68-8bab-950c-08cd5320df18'}
VMESS_WSPATH=${VMESS_WSPATH:-'/vmess'}
VLESS_WSPATH=${VLESS_WSPATH:-'/vless'}

# 2. 准备二进制文件 (使用绝对路径增加稳定性)
WORKDIR="/app"
RELEASE_RANDOMNESS=$(tr -dc 'A-Za-z0-9' </dev/urandom | head -c 6)
mv v ${RELEASE_RANDOMNESS}
chmod +x ${RELEASE_RANDOMNESS} et-linux-amd64 cloudflared

# 3. 配置并启动 Nginx (用于网页显示和分流)
sed -i "s#VMESS_WSPATH#${VMESS_WSPATH}#g;s#VLESS_WSPATH#${VLESS_WSPATH}#g" /etc/nginx/nginx.conf
nginx

# 4. 启动后端组件
# 1. 启动 X-Tunnel (监听 [::1]:8880)
nohup ./et-linux-amd64 -l ws://[::1]:8880 token a1b2c3 > xtunnel.log 2>&1 &

# 2. 内存流式启动 V2Ray
nohup ./${RELEASE_RANDOMNESS} -config=<(cat config | base64 -d | sed "s#UUID#$UUID#g;s#VMESS_WSPATH#${VMESS_WSPATH}#g;s#VLESS_WSPATH#${VLESS_WSPATH}#g") > v2.log 2>&1 &

# 5. 【后台运行】哪吒探针
if [ -n "${NEZHA_SERVER}" ] && [ -n "${NEZHA_PORT}" ] && [ -n "${NEZHA_KEY}" ]; then
    (
        wget https://raw.githubusercontent.com/naiba/nezha/master/script/install.sh -O nezha.sh && \
        chmod +x nezha.sh && echo '0' | ./nezha.sh install_agent ${NEZHA_SERVER} ${NEZHA_PORT} ${NEZHA_KEY} --tls
    ) &
fi

# 6. 启动 Cloudflared (核心修改：绝对路径 + 端口指向)
# 既然客户端不能填路径，我们必须直接指向 X-Tunnel 的 8880
sleep 3
nohup /app/cloudflared tunnel --no-autoupdate --url http://[::1]:8880 > cf_xt.log 2>&1 &

# 7. 生成主页内容 (回归你最喜欢的经典 grep 逻辑)
(
    echo "正在检索域名..."
    for i in {1..30}; do
        # 回归你最开始好用的 grep 方式
        DOMAIN_XT=$(grep -o 'https://[-a-z0-9.]*\.trycloudflare.com' cf_xt.log | head -n 1)
        
        if [ -n "$DOMAIN_XT" ]; then
            echo "成功获取域名: $DOMAIN_XT"
            cat <<EOF > /usr/share/nginx/html/index.html
<!DOCTYPE html>
<html>
<head><meta charset="UTF-8"><title>Success</title></head>
<body style="text-align:center; padding:50px; font-family:sans-serif;">
    <h1 style="color:#333;">🚀 服务已就绪</h1>
    <p>隧道地址: <b style="color:#f38020;">$DOMAIN_XT</b></p>
    <p style="color:red;">注意：客户端填地址和端口443，【不需要】填路径</p>
    <hr>
    <p style="font-size:0.8em; color:#666;">UUID: $UUID</p>
</body>
</html>
EOF
            break
        fi
        echo "第 $i 次尝试检索域名..."
        sleep 2
    done
) &

# 保持前台进程，防止容器退出
tail -f xtunnel.log
