# Use a standard Rust image
FROM rust:1.80.1-slim AS builder

WORKDIR /app

# Install only the absolutely necessary build tools
RUN apt-get update && apt install -yqq \
    cmake pkg-config libasound2-dev libssl-dev libpq-dev git curl

# Copy all files from your repository
COPY . .

# Build the bot normally without complex cross-compilation or caching
RUN cargo build --release

# Runtime Stage: This is the actual "bot" that runs
FROM debian:bookworm-slim

# Install runtime libraries
RUN apt update && apt install -y ca-certificates libpq-dev

# Copy the finished bot from the builder
COPY --from=builder /app/target/release/spoticord /usr/local/bin/spoticord

ENTRYPOINT [ "/usr/local/bin/spoticord" ]
