FROM alpine:latest

RUN apk add --no-cache bash

RUN apk add git

RUN apk add jq

RUN apk add curl

COPY entrypoint.sh /entrypoint.sh

RUN chmod 777 entrypoint.sh

ENTRYPOINT ["/entrypoint.sh"]