FROM rust:1.80.1-slim AS builder
WORKDIR /app

# Install dependencies
RUN apt-get update && apt install -yqq \
    cmake pkg-config libasound2-dev libssl-dev libpq-dev git curl

COPY . .

# Build (Works now because librespot 0.6.0 is public)
RUN cargo build --release

FROM debian:bookworm-slim
RUN apt update && apt install -y ca-certificates libpq-dev
COPY --from=builder /app/target/release/spoticord /usr/local/bin/spoticord
ENTRYPOINT [ "/usr/local/bin/spoticord" ]
