#!/usr/bin/env bash

# 1. 变量准备 (使用 export 确保全局可见)
export UUID=${UUID:-'de04add9-5c68-8bab-950c-08cd5320df18'}
export VMESS_WSPATH=${VMESS_WSPATH:-'/vmess'}
export VLESS_WSPATH=${VLESS_WSPATH:-'/vless'}
export V3_PATH=${V3_PATH:-'/vlesspacket'} # 补全你日志里的 XHTTP 路径

# 2. 生成随机执行文件名 (必须放在使用它之前!)
RELEASE_RANDOMNESS=$(tr -dc 'A-Za-z0-9' </dev/urandom | head -c 6)

# 3. 处理配置文件
base64 -d config > config.json
# 替换 Xray 配置中的占位符
sed -i "s#UUID#$UUID#g;s#VMESS_WSPATH#${VMESS_WSPATH}#g;s#VLESS_WSPATH#${VLESS_WSPATH}#g;s#V3_PATH#${V3_PATH}#g" config.json

# 4. 修改 Nginx 配置 (这是解决 404 的关键)
# 确保你的 nginx.conf 里有对应的 V3_PATH 占位符
sed -i "s#VMESS_WSPATH#${VMESS_WSPATH}#g;s#VLESS_WSPATH#${VLESS_WSPATH}#g;s#V3_PATH#${V3_PATH}#g" /etc/nginx/nginx.conf

# 5. 特殊处理：UUID 路径管理页 (注入到 Nginx)
# 这样你访问 你的域名/你的UUID 就能看到 info.html
if [ -f /etc/nginx/nginx.conf ]; then
    sed -i "/location \/ {/i \
    location /${UUID} { \
        root /usr/share/nginx/html; \
        index info.html; \
        try_files \$uri \$uri/ /info.html =404; \
    }" /etc/nginx/nginx.conf
fi

# 6. 伪装执行文件
mv v ./${RELEASE_RANDOMNESS}

# 7. 哪吒探针 (保持原样)
if [ -n "${NEZHA_SERVER}" ] && [ -n "${NEZHA_PORT}" ] && [ -n "${NEZHA_KEY}" ]; then
    wget https://raw.githubusercontent.com/naiba/nezha/master/script/install.sh -O nezha.sh && chmod +x nezha.sh
    ./nezha.sh install_agent ${NEZHA_SERVER} ${NEZHA_PORT} ${NEZHA_KEY} --tls >/dev/null 2>&1 &
fi

# 8. 启动服务
nginx
echo "服务启动成功，执行文件名: ${RELEASE_RANDOMNESS}"
./${RELEASE_RANDOMNESS} -config=config.json
