ARG BUILD_FROM
FROM ${BUILD_FROM}

RUN apk upgrade --no-cache && apk add --no-cache \
    jq \
    bash \
    socat \
    nginx

COPY rootfs /
COPY run.sh /

RUN chmod a+x /run.sh /usr/local/bin/generate-config.sh

CMD [ "/run.sh" ]
