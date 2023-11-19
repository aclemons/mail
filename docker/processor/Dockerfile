# syntax=docker/dockerfile:1.6.0@sha256:ac85f380a63b13dfcefa89046420e1781752bab202122f8f50032edf31be0021

FROM aclemons/slackware:15.0@sha256:10586533d3e9c5bf6e75341cd974a90acc152dd7d8d31bba17ce982dd63dd0df as slackware-base
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
    (cd processor && CARGO_HOME=.cargo cargo build --release && cp target/release/processor /tmp/processor-bin) && \
    rm -rf processor && mv /tmp/processor-bin /tmp/processor && \
    slackpkg -default_answer=yes -batch=on remove \
    binutils \
    gcc-11 \
    glibc \
    llvm-13 \
    pkg-config \
    rust \
    && rm -rf /var/cache/packages/* && rm -rf /var/lib/slackpkg/* && \
    echo "Built"

FROM base as jq

COPY docker/processor/build-jq.sh /
RUN bash /build-jq.sh && rm /build-jq.sh && installpkg /tmp/jq-* && rm -rf /tmp/jq*

FROM base
COPY --link --from=lambda-layers /tmp/layer /opt
COPY --link --from=rust --chmod=0755 /tmp/processor /usr/local/bin/processor
COPY --link --from=jq --chmod=0755 /usr/bin/jq /usr/bin/jq

COPY --link docker/processor/entrypoint.sh /entrypoint.sh

ENTRYPOINT ["/entrypoint.sh"]
