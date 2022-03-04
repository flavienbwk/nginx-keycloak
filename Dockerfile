FROM openresty/openresty:1.19.9.1-5-alpine-fat

RUN mkdir /var/log/nginx

RUN apk update && apk add --no-cache bash openssl-dev git gcc gettext
RUN luarocks install lua-resty-openidc
