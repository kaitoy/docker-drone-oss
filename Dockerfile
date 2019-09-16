FROM golang:1.12.9-alpine3.10 AS build

ENV DRONE_VER=1.4.0

RUN apk update \
    && \
    apk add --no-cache \
        gcc \
        musl-dev \
        git \
    && \
    wget -O drone.zip "https://github.com/drone/drone/archive/v${DRONE_VER}.zip" \
    && \
    unzip drone.zip \
    && \
    mkdir -p src/github.com/drone/ \
    && \
    mv "drone-${DRONE_VER}" src/github.com/drone/drone \
    && \
    sed -i -e 's/package converter/package validator/' src/github.com/drone/drone/plugin/validator/noop.go \
    && \
    sed -i -e 's/core.ConvertArgs/core.ValidateArgs/' src/github.com/drone/drone/plugin/validator/noop.go \
    && \
    sed -i -e '14i// +build !oss' src/github.com/drone/drone/plugin/converter/memoize.go \
    && \
    sed -i -e 's/notImplemented/rollbackNotImplemented/g' src/github.com/drone/drone/handler/api/repos/builds/rollback_oss.go

COPY legacy_oss.go src/github.com/drone/drone/plugin/converter/
COPY memoize_oss.go src/github.com/drone/drone/plugin/converter/
COPY remote_oss.go src/github.com/drone/drone/plugin/converter/

WORKDIR src/github.com/drone/drone

RUN GO111MODULE=on go build -tags "oss nolimit" -o drone-server ./cmd/drone-server

FROM alpine:3.10

COPY --from=build /go/src/github.com/drone/drone/drone-server /

ENV DRONE_DATABASE_DRIVER sqlite3
ENV DRONE_DATABASE_DATASOURCE /data/database.sqlite
ENV DRONE_SERVER_PROTO http
ENV DRONE_SERVER_PORT :8080
ENV DRONE_AGENTS_ENABLED false
ENV DRONE_RUNNER_LOCAL true
ENV DRONE_RUNNER_CAPACITY 4
ENV DRONE_REPOSITORY_TRUSTED true

EXPOSE 8080

RUN apk update \
    && \
    apk add --no-cache \
      ca-certificates \
    && \
    mkdir /data

ENTRYPOINT ["/drone-server"]
