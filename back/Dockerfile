# Stage 1: Build the backend
FROM rust:1.85-slim AS builder

WORKDIR /app

# Copy the Cargo.toml to cache dependencies
COPY Cargo.toml ./

# Create a dummy src/main.rs to build dependencies and cache them
RUN mkdir src && echo "fn main() {}" > src/main.rs
RUN cargo build --release
RUN rm -rf src

# Copy the real source code
COPY src ./src

# Rebuild with real source
RUN touch src/main.rs && cargo build --release

# Stage 2: Minimal runtime image
FROM debian:bookworm-slim

RUN apt-get update && apt-get install -y --no-install-recommends ca-certificates && rm -rf /var/lib/apt/lists/*

WORKDIR /app

# Copy the binary from builder stage
COPY --from=builder /app/target/release/spotme-back .

ENV PORT=8080
EXPOSE 8080

CMD ["./spotme-back"]
