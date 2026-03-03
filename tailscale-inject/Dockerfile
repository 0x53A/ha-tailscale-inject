ARG BUILD_FROM
FROM ${BUILD_FROM}

RUN apk add --no-cache \
    docker-cli \
    docker-cli-compose \
    jq \
    bash

COPY rootfs /
COPY run.sh /

RUN chmod a+x /run.sh /usr/local/bin/generate-compose.sh /usr/local/bin/ts-entrypoint.sh

CMD [ "/run.sh" ]
