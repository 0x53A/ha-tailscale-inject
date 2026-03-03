ARG BUILD_FROM
FROM ${BUILD_FROM}

RUN apk upgrade --no-cache && apk add --no-cache \
    docker-cli \
    docker-cli-compose \
    jq \
    bash \
    nmap

COPY rootfs /
COPY run.sh /

RUN chmod a+x /run.sh /usr/local/bin/generate-compose.sh /usr/local/bin/ts-entrypoint.sh

CMD [ "/run.sh" ]
