FROM nginx:latest
EXPOSE 80
WORKDIR /app
USER root

RUN apt-get update && apt-get install -y wget unzip iproute2 ca-certificates && \
    wget -O temp.zip https://github.com/XTLS/Xray-core/releases/latest/download/Xray-linux-64.zip && \
    unzip temp.zip xray geoip.dat geosite.dat && \
    mv xray v && rm -f temp.zip && chmod -v 755 v

COPY nginx.conf /etc/nginx/nginx.conf
COPY entrypoint.sh ./
RUN chmod +x entrypoint.sh

ENTRYPOINT [ "./entrypoint.sh" ]
