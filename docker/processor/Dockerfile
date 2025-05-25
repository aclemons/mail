# syntax=docker/dockerfile:1.15.1@sha256:9857836c9ee4268391bb5b09f9f157f3c91bb15821bb77969642813b0d00518d

FROM aclemons/slackware:15.0@sha256:d79adbea0b2bed58b1c6cb733c1ed0b32dd9981a6ac90a1f1b2baca66f3a9be8 AS slackware-base
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
    readline \
    && \
    rm -rf /var/cache/packages/* && rm -rf /var/lib/slackpkg/* && \
    c_rehash && update-ca-certificates


FROM base AS rust

WORKDIR /tmp

COPY docker/processor/build-rust-opt.sh .
COPY processor processor

# hadolint ignore=DL3003
RUN export TERSE=0 && slackpkg -default_answer=yes -batch=on update && \
    slackpkg -default_answer=yes -batch=on install \
    binutils \
    gcc-11 \
    glibc \
    kernel-headers \
    llvm-13 \
    pkg-config \
    && \
    bash build-rust-opt.sh && rm build-rust-opt.sh && installpkg /tmp/rust-opt-* && rm -rf /tmp/rust-opt* && \
    (cd processor && PATH="/opt/rust/bin:$PATH" LD_LIBRARY_PATH="/opt/rust/lib64" CARGO_HOME=.cargo cargo build --release && cp target/release/processor /tmp/processor-bin) && \
    rm -rf processor && mv /tmp/processor-bin /tmp/processor && \
    slackpkg -default_answer=yes -batch=on remove \
    binutils \
    gcc-11 \
    glibc \
    kernel-headers \
    llvm-13 \
    pkg-config \
    && rm -rf /var/cache/packages/* && rm -rf /var/lib/slackpkg/* && \
    removepkg rust-opt && \
    echo "Built"

FROM base AS jq

COPY docker/processor/build-jq.sh /
RUN bash /build-jq.sh && rm /build-jq.sh && installpkg /tmp/jq-* && rm -rf /tmp/jq*

FROM base AS lambda-tools

# renovate: datasource=github-releases depName=aws/aws-lambda-runtime-interface-emulator
ENV AWS_LAMBDA_RIE_VERSION=v1.25

WORKDIR /tmp
RUN \
    curl -o /usr/local/bin/aws-lambda-rie -L "https://github.com/aws/aws-lambda-runtime-interface-emulator/releases/download/$AWS_LAMBDA_RIE_VERSION/aws-lambda-rie-x86_64" && \
    chown root:root /usr/local/bin/aws-lambda-rie && chmod 0755 /usr/local/bin/aws-lambda-rie

FROM base
COPY --link --from=lambda-tools /usr/local/bin/aws-lambda-rie /usr/local/bin/aws-lambda-rie
COPY --link --from=lambda-layers /tmp/layer /opt
COPY --link --from=rust --chmod=0755 /tmp/processor /usr/local/bin/processor
COPY --link --from=jq --chmod=0755 /usr/bin/jq /usr/bin/jq

COPY --link docker/processor/local.sh /local.sh
COPY --link docker/processor/entrypoint.sh /entrypoint.sh

ENTRYPOINT ["/local.sh"]
