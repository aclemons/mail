# syntax=docker/dockerfile:1.6.0

FROM aclemons/slackware:15.0@sha256:f5be608613a644de34677d7431353e6c2c53266697e4edc218ec9cab6fb656e1 as slackware-base
RUN sed -i '/^WGETFLAGS/s/"$/ -q"/' /etc/slackpkg/slackpkg.conf


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


FROM base as rust

WORKDIR /tmp

COPY processor processor

# hadolint ignore=DL3003
RUN sed -i '/PRIORITY=/s/extra //;/PRIORITY=/s/patches /patches extra /' /etc/slackpkg/slackpkg.conf && \
    export TERSE=0 && slackpkg -default_answer=yes -batch=on update && \
    slackpkg -default_answer=yes -batch=on install \
    binutils \
    gcc-11 \
    glibc \
    llvm-13 \
    pkg-config \
    rust \
    && \
    rm -rf /var/cache/packages/* && rm -rf /var/lib/slackpkg/* && \
    (cd processor && CARGO_HOME=.cargo cargo build --release && cp target/release/processor /tmp/processor-bin) && \
    rm -rf processor && mv /tmp/processor-bin /tmp/processor && \
    slackpkg -default_answer=yes -batch=on remove \
    binutils \
    gcc-11 \
    glibc \
    llvm-13 \
    pkg-config \
    rust \
    && echo "Built"

FROM base
COPY --from=lambda-layers /tmp/layer /opt
COPY --from=rust --chmod=0755 /tmp/processor /usr/local/bin/processor

COPY docker/processor/entrypoint.sh /entrypoint.sh

ENTRYPOINT ["/entrypoint.sh"]
