# syntax=docker/dockerfile:1
FROM ghcr.io/linuxserver/baseimage-alpine:3.17

# set version label
ARG BUILD_DATE
ARG VERSION
ARG OVERSEERR_VERSION
LABEL build_version="Linuxserver.io version:- ${VERSION} Build-date:- ${BUILD_DATE}"
LABEL maintainer="nemchik"

# set environment variables
ENV HOME="/config"
ENV PUID=1000
ENV PGID=1000
ENV TZ=Europe/Berlin

# Install gcsfuse
ENV GCSFUSE_REPO=gcsfuse-alpine
RUN echo "https://packages.cloud.google.com/apt $GCSFUSE_REPO main" > /etc/apk/repositories/$GCSFUSE_REPO && \
    curl -s https://packages.cloud.google.com/apt/doc/apt-key.gpg | apk add --no-cache --virtual=build-dependencies --repository https://packages.cloud.google.com/apt gcsfuse

RUN \
  echo "**** install build packages ****" && \
  apk add --no-cache --virtual=build-dependencies \
    build-base \
    python3 && \
  echo "**** install runtime packages ****" && \
  apk add --no-cache \
    yarn && \
  if [ -z ${OVERSEERR_VERSION+x} ]; then \
    OVERSEERR_VERSION=$(curl -sX GET "https://api.github.com/repos/sct/overseerr/releases/latest" \
    | awk '/tag_name/{print $4;exit}' FS='[""]'); \
  fi && \
  export COMMIT_TAG="${OVERSEERR_VERSION}" && \
  curl -o \
    /tmp/overseerr.tar.gz -L \
    "https://github.com/sct/overseerr/archive/${OVERSEERR_VERSION}.tar.gz" && \
  mkdir -p /app/overseerr && \
  tar xzf \
    /tmp/overseerr.tar.gz -C \
    /app/overseerr/ --strip-components=1 && \
  cd /app/overseerr && \
  export NODE_OPTIONS=--max_old_space_size=2048 && \
  CYPRESS_INSTALL_BINARY=0 yarn --frozen-lockfile --network-timeout 1000000 && \
  yarn build && \
  yarn install --production --ignore-scripts --prefer-offline && \
  yarn cache clean && \
  rm -rf \
    /app/overseerr/src \
    /app/overseerr/server && \
  echo "{\"commitTag\": \"${COMMIT_TAG}\"}" > committag.json && \
  rm -rf /app/overseerr/config && \
  ln -s /config /app/overseerr/config && \
  touch /config/DOCKER && \
  echo "**** cleanup ****" && \
  apk del --purge \
    build-dependencies && \
  rm -rf \
    /root/.cache \
    /tmp/* \
    /app/overseerr/.next/cache/*

# copy local files
COPY root/ /
COPY entrypoint.sh /entrypoint.sh

# ports and volumes
EXPOSE 5055
VOLUME /config

ENTRYPOINT ["/bin/sh", "/entrypoint.sh"]
