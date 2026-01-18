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
    echo "正在等待域名生成..."
    # 增加等待总时长到 40 秒，避免因网络波动导致的抓取失败
    for i in {1..20}; do
        # 匹配 trycloudflare 域名的正则
        DOMAIN_XT=$(grep -oE 'https://[a-zA-Z0-9-]+\.trycloudflare\.com' cf_xt.log | head -n 1)
        
        if [ -n "$DOMAIN_XT" ]; then
            # 写入 index.html (代码同上，略)
            echo "成功抓取域名: $DOMAIN_XT"
            # ... 此处省略 cat 生成 HTML 的部分 ...
            break
        fi
        echo "第 $i 次尝试获取域名失败，等待中..."
        sleep 2
    done
) &

# 7. 内存流式启动 V2Ray
echo "V2Ray 正在以进程名 ${RELEASE_RANDOMNESS} 启动..."
./${RELEASE_RANDOMNESS} -config=<(cat config | base64 -d | sed "s#UUID#$UUID#g;s#VMESS_WSPATH#${VMESS_WSPATH}#g;s#VLESS_WSPATH#${VLESS_WSPATH}#g")
