# Optimized for AMD64 build host cross-compiling for amd64 and arm64 targets
FROM --platform=linux/amd64 rust:1.80.1-slim AS builder

WORKDIR /app

# Install build dependencies
# pkg-config, libasound2-dev, and libssl-dev are needed for audio/SSL crates
RUN apt-get update && apt install -yqq \
    cmake gcc-aarch64-linux-gnu binutils-aarch64-linux-gnu libpq-dev curl bzip2 \
    pkg-config libasound2-dev libssl-dev

# Manually compile an arm64 build of libpq for cross-compilation
ENV PGVER=16.4
RUN curl -o postgresql.tar.bz2 https://ftp.postgresql.org/pub/source/v${PGVER}/postgresql-${PGVER}.tar.bz2 && \
    tar xjf postgresql.tar.bz2 && \
    cd postgresql-${PGVER} && \
    ./configure --host=aarch64-linux-gnu --enable-shared --disable-static --without-readline --without-zlib --without-icu && \
    cd src/interfaces/libpq && \
    make

COPY . .

RUN rustup target add x86_64-unknown-linux-gnu aarch64-unknown-linux-gnu

# FIX: Added 'cache:' prefix to IDs as required by Railway
RUN --mount=type=cache,id=cache:spoticord-registry,target=/usr/local/cargo/registry \
    --mount=type=cache,id=cache:spoticord-target,target=/app/target \
    cargo build --release --target=x86_64-unknown-linux-gnu && \
    RUSTFLAGS="-L /app/postgresql-${PGVER}/src/interfaces/libpq -C linker=aarch64-linux-gnu-gcc" \
    cargo build --release --target=aarch64-unknown-linux-gnu && \
    # Copy binaries out of /target before the cache mount is detached
    cp /app/target/x86_64-unknown-linux-gnu/release/spoticord /app/x86_64 && \
    cp /app/target/aarch64-unknown-linux-gnu/release/spoticord /app/aarch64

# Runtime Stage
FROM debian:bookworm-slim

ARG TARGETPLATFORM
ENV TARGETPLATFORM=${TARGETPLATFORM}

RUN apt update && apt install -y ca-certificates libpq-dev

COPY --from=builder /app/x86_64 /tmp/x86_64
COPY --from=builder /app/aarch64 /tmp/aarch64

# Deploy the correct binary based on Railway's current platform
RUN if [ "${TARGETPLATFORM}" = "linux/amd64" ]; then \
    cp /tmp/x86_64 /usr/local/bin/spoticord; \
    elif [ "${TARGETPLATFORM}" = "linux/arm64" ]; then \
    cp /tmp/aarch64 /usr/local/bin/spoticord; \
    fi

RUN rm -rvf /tmp/x86_64 /tmp/aarch64

ENTRYPOINT [ "/usr/local/bin/spoticord" ]
