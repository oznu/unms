# Multi-stage build - See https://docs.docker.com/engine/userguide/eng-image/multistage-build
FROM ubnt/unms:0.11.1-alpha2 as unms

FROM oznu/s6-node:8.9.3

# Copy UNMS app from offical image since the source code is not published at this time
COPY --from=unms /home/app/unms /app

WORKDIR /app

RUN devDeps="vips-dev fftw-dev make python g++" \
  && sed -i 's/edge\/community/edge\/testing/g' /etc/apk/repositories \
  && apk add --no-cache ${devDeps} bash gzip vips openssl postgresql redis rabbitmq-server \
  && rm -rf /app/node_modules \
  && yarn install --ignore-engines \
  && apk del ${devDeps} \
  && deluser rabbitmq \
  && addgroup -S rabbitmq && adduser -S -h /var/lib/rabbitmq -G rabbitmq rabbitmq \
  && mkdir -p /var/lib/rabbitmq /etc/rabbitmq \
  && chown -R rabbitmq:rabbitmq /var/lib/rabbitmq /etc/rabbitmq \
  && chmod -R 777 /var/lib/rabbitmq /etc/rabbitmq \
  && ln -sf /var/lib/rabbitmq/.erlang.cookie /root/

RUN devDeps="musl-dev gcc python python-dev py-pip libffi-dev openssl-dev" \
  && apk add --no-cache sudo dumb-init certbot openssl nginx nginx-mod-http-lua ${devDeps} \
  && pip install -U certbot-nginx \
  && apk del ${devDeps} \
  && echo "abc ALL=(ALL) NOPASSWD: /usr/sbin/nginx -s *" >> /etc/sudoers

ENV NODE_ENV=production \
  PATH=/app/node_modules/.bin:$PATH \
  PGDATA=/config/postgres \
  POSTGRES_DB=unms \
  HOME=/var/lib/rabbitmq \
  PROD=true \
  HTTPS_PORT=443 \
  PUBLIC_HTTPS_PORT=443 \
  PUBLIC_WS_PORT=443 \
  UNMS_FLUENTD_PORT=80

EXPOSE 80 443

VOLUME ["/config"]

COPY root /
