FROM crystallang/crystal:1.16.3-alpine AS builder

RUN apk add --no-cache sqlite-static yaml-static

ARG release

WORKDIR /invidious
COPY ./shard.yml ./shard.yml
COPY ./shard.lock ./shard.lock
RUN shards install --production

COPY ./src/ ./src/
COPY ./scripts/ ./scripts/
COPY ./assets/ ./assets/
COPY ./videojs-dependencies.yml ./videojs-dependencies.yml

RUN crystal spec --warnings all --link-flags "-lxml2 -llzma"

# Removed the cache mount here and simplified build command
RUN if [[ "${release}" == 1 ]] ; then \
        crystal build ./src/invidious.cr \
        --release \
        --static --warnings all \
        --link-flags "-lxml2 -llzma"; \
    else \
        crystal build ./src/invidious.cr \
        --static --warnings all \
        --link-flags "-lxml2 -llzma"; \
    fi

FROM alpine:3.21
RUN apk add --no-cache rsvg-convert ttf-opensans tini tzdata

WORKDIR /invidious
RUN addgroup -g 1000 -S invidious && \
    adduser -u 1000 -S invidious -G invidious

COPY --chown=invidious ./config/config.* ./config/
RUN mv -n config/config.example.yml config/config.yml
RUN sed -i 's/host: \(127.0.0.1\|localhost\)/host: invidious-db/' config/config.yml

COPY ./config/sql/ ./config/sql/
COPY ./locales/ ./locales/
COPY --from=builder /invidious/assets ./assets/
COPY --from=builder /invidious/invidious .

RUN chmod o+rX -R ./assets ./config ./locales

EXPOSE 3000
USER invidious
ENTRYPOINT ["/sbin/tini", "--"]
CMD ["/invidious/invidious"]
