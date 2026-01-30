# Optimized for AMD64 build hosts
FROM --platform=linux/amd64 rust:1.80.1-slim AS builder

WORKDIR /app

# Install build dependencies + networking libs
RUN apt-get update && apt install -yqq \
    cmake gcc-aarch64-linux-gnu binutils-aarch64-linux-gnu libpq-dev curl bzip2 \
    pkg-config libasound2-dev libssl-dev git

# Manually compile an arm64 build of libpq
ENV PGVER=16.4
RUN curl -o postgresql.tar.bz2 https://ftp.postgresql.org/pub/source/v${PGVER}/postgresql-${PGVER}.tar.bz2 && \
    tar xjf postgresql.tar.bz2 && \
    cd postgresql-${PGVER} && \
    ./configure --host=aarch64-linux-gnu --enable-shared --disable-static --without-readline --without-zlib --without-icu && \
    cd src/interfaces/libpq && \
    make

COPY . .

RUN rustup target add x86_64-unknown-linux-gnu aarch64-unknown-linux-gnu

# BUILD 1: Standard x86 build
RUN PQ_LIB_DIR=/usr/lib/x86_64-linux-gnu cargo build --release --target=x86_64-unknown-linux-gnu && \
    cp /app/target/x86_64-unknown-linux-gnu/release/spoticord /app/x86_64

# BUILD 2: Cross-compile ARM build (Separated to prevent OOM/101 errors)
RUN RUSTFLAGS="-L /app/postgresql-${PGVER}/src/interfaces/libpq -C linker=aarch64-linux-gnu-gcc" \
    cargo build --release --target=aarch64-unknown-linux-gnu && \
    cp /app/target/aarch64-unknown-linux-gnu/release/spoticord /app/aarch64

# Runtime Stage
FROM debian:bookworm-slim
ARG TARGETPLATFORM
ENV TARGETPLATFORM=${TARGETPLATFORM}

RUN apt update && apt install -y ca-certificates libpq-dev

COPY --from=builder /app/x86_64 /tmp/x86_64
COPY --from=builder /app/aarch64 /tmp/aarch64

RUN if [ "${TARGETPLATFORM}" = "linux/amd64" ]; then \
    cp /tmp/x86_64 /usr/local/bin/spoticord; \
    else \
    cp /tmp/aarch64 /usr/local/bin/spoticord; \
    fi

RUN rm -rvf /tmp/x86_64 /tmp/aarch64
ENTRYPOINT [ "/usr/local/bin/spoticord" ]
