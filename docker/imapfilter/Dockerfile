# syntax=docker/dockerfile:1.6.0

FROM aclemons/slackware:15.0@sha256:55c43e5e565e3e8e35761051abec9510b8d581b5b32358170d1bc0e351ee118a as slackware-base

FROM slackware-base as lambda-layers

WORKDIR /tmp
RUN --mount=target=/layers,source=docker/shared/layers \
    export TERSE=0 && slackpkg -default_answer=yes -batch=on update && \
    slackpkg -default_answer=yes -batch=on install \
    infozip \
    && \
    rm -rf /var/cache/packages/* && rm -rf /var/lib/slackpkg/* && \
    unzip -q -d /tmp/layer /layers/lambda-insights-amd64-*.zip && \
    unzip -q -d /tmp/layer /layers/parameters-and-secrets-amd64-*.zip && \
    removepkg infozip


FROM slackware-base as base

RUN export TERSE=0 && slackpkg -default_answer=yes -batch=on update && \
    slackpkg -default_answer=yes -batch=on install \
    bison \
    brotli \
    ca-certificates \
    curl \
    cyrus-sasl \
    dcron \
    flex \
    nghttp2 \
    oniguruma \
    perl \
    readline \
    && \
    rm -rf /var/cache/packages/* && rm -rf /var/lib/slackpkg/* && \
    c_rehash && update-ca-certificates


FROM base as imapfilter

COPY docker/imapfilter/build-imapfilter.sh /
RUN bash /build-imapfilter.sh && rm /build-imapfilter.sh


FROM base
COPY --from=lambda-layers /tmp/layer /opt
RUN --mount=target=/tmp,source=tmp,from=imapfilter \
    installpkg /tmp/*.txz

COPY docker/imapfilter/entrypoint.sh /entrypoint.sh

WORKDIR /imapfilter
COPY docker/imapfilter/config.lua /imapfilter/config.lua
COPY docker/imapfilter/run.sh /imapfilter/run.sh

ENTRYPOINT ["/entrypoint.sh"]