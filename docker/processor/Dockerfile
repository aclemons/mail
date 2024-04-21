# syntax=docker/dockerfile:1.7.0@sha256:dbbd5e059e8a07ff7ea6233b213b36aa516b4c53c645f1817a4dd18b83cbea56

FROM aclemons/slackware:15.0@sha256:4f52bfa9387d71ac29392d386ea41a017a8dbedfa7b0824bdef90b1b83d90183 as slackware-base
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

FROM base as lambda-tools

# renovate: datasource=github-releases depName=aws/aws-lambda-runtime-interface-emulator
ENV AWS_LAMBDA_RIE_VERSION=v1.18

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
