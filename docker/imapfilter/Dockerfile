# syntax=docker/dockerfile:1.6.0

FROM aclemons/slackware:15.0@sha256:4f7d2a0a65ab072d25c9a12f00cbd4f92edfa689da229e6f7cc5a3f0b15b00f4 as base

RUN export TERSE=0 && slackpkg -default_answer=yes -batch=on update && \
    slackpkg -default_answer=yes -batch=on install \
    brotli \
    ca-certificates \
    curl \
    cyrus-sasl \
    dcron \
    flex \
    nghttp2 \
    perl \
    readline \
    && \
    rm -rf /var/cache/packages/* && rm -rf /var/lib/slackpkg/* && \
    c_rehash && update-ca-certificates


FROM base as imapfilter

COPY docker/imapfilter/build-imapfilter.sh /
RUN bash /build-imapfilter.sh && rm /build-imapfilter.sh


FROM base
RUN --mount=target=/tmp,source=tmp,from=imapfilter \
    installpkg /tmp/*.txz

COPY docker/imapfilter/entrypoint.sh /entrypoint.sh

ENTRYPOINT ["/entrypoint.sh"]
