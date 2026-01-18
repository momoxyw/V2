#!/usr/bin/env bash

# 1. 变量初始化
UUID=${UUID:-'de04add9-5c68-8bab-950c-08cd5320df18'}
VMESS_WSPATH=${VMESS_WSPATH:-'/vmess'}
VLESS_WSPATH=${VLESS_WSPATH:-'/vless'}
XTUNNEL_WSPATH='/xtunnel'  # 为 X-Tunnel 指定路径

# 2. 准备二进制文件
RELEASE_RANDOMNESS=$(tr -dc 'A-Za-z0-9' </dev/urandom | head -c 6)
mv v ${RELEASE_RANDOMNESS}
chmod +x ${RELEASE_RANDOMNESS} et-linux-amd64 cloudflared

# 3. 立即配置并启动 Nginx (统一流量分发层)
# 替换 VMESS, VLESS 路径，并确保配置已包含上文提到的 /xtunnel 转发
sed -i "s#VMESS_WSPATH#${VMESS_WSPATH}#g;s#VLESS_WSPATH#${VLESS_WSPATH}#g" /etc/nginx/nginx.conf
nginx

# 4. 启动组件
# A. X-Tunnel 依然监听本地 IPv6 回环
nohup ./et-linux-amd64 -l ws://[::1]:8880 token a1b2c3 > xtunnel.log 2>&1 &

# B. Cloudflared 去掉 --protocol quic
# 默认模式下，它会使用标准的 HTTPS/2 隧道，兼容性最强
sleep 3
nohup ./cloudflared tunnel --no-autoupdate --url http://[::1]:80 > cf_xt.log 2>&1 &

# 5. 【后台运行】哪吒探针
if [ -n "${NEZHA_SERVER}" ] && [ -n "${NEZHA_PORT}" ] && [ -n "${NEZHA_KEY}" ]; then
    (
        wget https://raw.githubusercontent.com/naiba/nezha/master/script/install.sh -O nezha.sh && \
        chmod +x nezha.sh && echo '0' | ./nezha.sh install_agent ${NEZHA_SERVER} ${NEZHA_PORT} ${NEZHA_KEY} --tls
    ) &
fi

# 6. 生成主页内容 (增强版：持续监测直到域名出现)
(
    echo "正在从日志深度检索域名..."
    for i in {1..20}; do
        # 这里的正则去掉了 https:// 前缀的要求，防止日志里格式变化
        DOMAIN_RAW=$(grep -oE "[a-zA-Z0-9-]+\.trycloudflare\.com" cf_xt.log | head -n 1)
        
        if [ -n "$DOMAIN_RAW" ]; then
            DOMAIN_XT="https://$DOMAIN_RAW"
            echo "成功获取域名: $DOMAIN_XT"
            
            # 生成 index.html
            cat <<EOF > /usr/share/nginx/html/index.html
<!DOCTYPE html>
<html>
<head><meta charset="UTF-8"><title>Service Online</title></head>
<body style="text-align:center; padding:50px; font-family:sans-serif; background:#f4f4f4;">
    <div style="background:white; display:inline-block; padding:30px; border-radius:15px; shadow: 0 4px 6px rgba(0,0,0,0.1);">
        <h1 style="color:#0078d4;">🚀 隧道连接成功</h1>
        <p>访问地址: <a href="$DOMAIN_XT" style="color:#f38020; font-weight:bold; text-decoration:none;">$DOMAIN_XT</a></p>
        <p style="color:#666;">后端协议: IPv6 [::1] (Non-QUIC Mode)</p>
        <hr>
        <div style="text-align:left; font-size:13px;">
            <p><b>X-Tunnel:</b> $DOMAIN_XT/xtunnel</p>
            <p><b>V2Ray VMESS:</b> $DOMAIN_XT$VMESS_WSPATH</p>
            <p><b>V2Ray VLESS:</b> $DOMAIN_XT$VLESS_WSPATH</p>
        </div>
    </div>
</body>
</html>
EOF
            break
        fi
        echo "第 $i 次尝试检索失败，正在检查日志内容..."
        # 调试用：如果失败，输出日志最后两行看看
        tail -n 2 cf_xt.log
        sleep 2
    done
) &

# 7. 内存流式启动 V2Ray
echo "V2Ray 正在以进程名 ${RELEASE_RANDOMNESS} 启动..."
./${RELEASE_RANDOMNESS} -config=<(cat config | base64 -d | sed "s#UUID#$UUID#g;s#VMESS_WSPATH#${VMESS_WSPATH}#g;s#VLESS_WSPATH#${VLESS_WSPATH}#g")
