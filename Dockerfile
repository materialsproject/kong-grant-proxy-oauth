FROM kong:2.8.3-alpine

USER root
ARG VERSION
ENV LUA_PATH=/usr/local/share/lua/5.1/?.lua;; \
  DD_SERVICE=kong \
  DD_ENV=prod \
  DD_VERSION=$VERSION \
  DD_PROFILING_ENABLED=true \
  DD_LOGS_INJECTION=true \
  KONG_DATABASE=postgres \
  KONG_PG_PORT=5432 \
  KONG_PLUGINS=acl,bot-detection,cors,key-auth,session,request-size-limiting,datadog,jwt,prometheus,rate-limiting,response-ratelimiting,request-transformer,grant-proxy-oauth,redirect,request-termination \
  KONG_ADMIN_ACCESS_LOG=/dev/stdout \
  KONG_ADMIN_ERROR_LOG=/dev/stderr \
  KONG_PROXY_ACCESS_LOG="/dev/stdout json_combined" \
  KONG_PROXY_ERROR_LOG=/dev/stderr \
  KONG_NGINX_WORKER_PROCESSES=2 \
  KONG_NGINX_EVENTS_WORKER_CONNECTIONS=10000 \
  KONG_NGINX_HTTP_CLIENT_BODY_BUFFER_SIZE=1m \
  KONG_NGINX_HTTP_LUA_SHARED_DICT="prometheus_metrics 30m" \
  KONG_NGINX_PROXY_PROXY_IGNORE_CLIENT_ABORT=on \
  KONG_NGINX_PROXY_PROXY_HTTP_VERSION=1.1 \
  KONG_MEM_CACHE_SIZE=1000m \
  KONG_ANONYMOUS_REPORTS=off \
  KONG_NGINX_HTTP_LUA_SHARED_DICT="prometheus_metrics 30m" \
  COOKIE_DOMAIN=".materialsproject.org"

RUN apk add git lua5.4 lua5.4-dev make openssl openssl-dev build-base
RUN git clone --depth 1 https://github.com/luarocks/luarocks
RUN cd luarocks && ./configure --prefix=/usr/local/openresty/luajit --lua-version=5.4 && make && make install
RUN luarocks config lua_version 5.1

RUN apk add --no-cache wget curl httpie postgresql-client && \
  wget -q https://raw.githubusercontent.com/tschaume/kong/feat/persistent-cookie/kong/plugins/session/schema.lua && \
  mv schema.lua /usr/local/share/lua/5.1/kong/plugins/session/ && \
  wget -q https://raw.githubusercontent.com/tschaume/kong/feat/persistent-cookie/kong/plugins/session/session.lua && \
  mv session.lua /usr/local/share/lua/5.1/kong/plugins/session/ && \
  chmod -R a+r /usr/local/share/lua/5.1/kong/plugins/session

WORKDIR grant-proxy-oauth
COPY handler.lua .
COPY schema.lua .
COPY kong-grant-proxy-oauth-0.0-0.rockspec .
#RUN luarocks install penlight
RUN /usr/local/openresty/luajit/bin/luarocks install --tree /usr/local lua-resty-cookie
RUN /usr/local/openresty/luajit/bin/luarocks install --tree /usr/local luaossl \
  CRYPTO_DIR=/usr \
  LUA_INCDIR=/usr/local/openresty/luajit/include/luajit-2.1
RUN /usr/local/openresty/luajit/bin/luarocks install --tree /usr/local kong-plugin-redirect

RUN /usr/local/openresty/luajit/bin/luarocks --tree /usr/local/ make

COPY --chmod=755 start.sh .
COPY --chmod=755 custom-nginx.template .

LABEL com.datadoghq.ad.check_names='["kong"]'
LABEL com.datadoghq.ad.init_configs='[{}]'
LABEL com.datadoghq.ad.instances='[{"openmetrics_endpoint": "http://%%host%%:8001/metrics"}]'
LABEL com.datadoghq.ad.logs='[{"source": "kong", "service": "kong", "log_processing_rules": [{"type": "exclude_at_match", "name": "exclude_logs", "pattern": "(?:queryDns)|(?:\"status_code\":\\s20)"}]}]'

USER kong
CMD ./start.sh
