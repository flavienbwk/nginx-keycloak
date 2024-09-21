FROM openresty/openresty:1.25.3.2-0-alpine-fat

RUN mkdir /var/log/nginx

RUN apk update && apk add --no-cache bash openssl-dev git gcc gettext
RUN luarocks install lua-resty-openidc
