# syntax=docker/dockerfile:1.16.0@sha256:e2dd261f92e4b763d789984f6eab84be66ab4f5f08052316d8eb8f173593acf7

FROM aclemons/slackware:15.0@sha256:b9e7dffe90441fd6e5440d9cbeef4ef1e9692f5f8b909758cc7c7e6c5d1d5666 AS slackware-base
RUN sed -i '/^WGETFLAGS/s/"$/ -q"/' /etc/slackpkg/slackpkg.conf


FROM slackware-base AS lambda-layers

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

FROM slackware-base AS base

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
    python3 \
    readline \
    && \
    rm -rf /var/cache/packages/* && rm -rf /var/lib/slackpkg/* && \
    c_rehash && update-ca-certificates

ARG GMAIL_OAUTH2_TOOLS_SHA=85c6b4f07e637683cc5e0ec6a66ce8e4397a4b18
RUN curl -f -o /usr/bin/oauth2.py https://raw.githubusercontent.com/google/gmail-oauth2-tools/$GMAIL_OAUTH2_TOOLS_SHA/python/oauth2.py && chmod 0755 /usr/bin/oauth2.py


FROM base AS lambda-tools

# renovate: datasource=github-releases depName=aws/aws-lambda-runtime-interface-emulator
ENV AWS_LAMBDA_RIE_VERSION=v1.25

WORKDIR /tmp
RUN \
    curl -o /usr/local/bin/aws-lambda-rie -L "https://github.com/aws/aws-lambda-runtime-interface-emulator/releases/download/$AWS_LAMBDA_RIE_VERSION/aws-lambda-rie-x86_64" && \
    chown root:root /usr/local/bin/aws-lambda-rie && chmod 0755 /usr/local/bin/aws-lambda-rie


FROM base AS imapfilter

COPY docker/imapfilter/build-imapfilter.sh /
RUN bash /build-imapfilter.sh && rm /build-imapfilter.sh


FROM base
RUN --mount=target=/tmp,source=tmp,from=imapfilter \
    installpkg /tmp/*.txz

COPY --link --from=lambda-tools /usr/local/bin/aws-lambda-rie /usr/local/bin/aws-lambda-rie
COPY --link --from=lambda-layers /tmp/layer /opt

COPY --link docker/imapfilter/local.sh /local.sh
COPY --link docker/imapfilter/entrypoint.sh /entrypoint.sh

WORKDIR /imapfilter
COPY --link docker/imapfilter/config.lua /imapfilter/config.lua
COPY --link docker/imapfilter/run.sh /imapfilter/run.sh

ENTRYPOINT ["/local.sh"]
