# Builds the Rust (Windows/Linux) server for Linux and runs it over stdio.
#
# This image exists so registries such as Glama can start the server and
# introspect it (`initialize`, `tools/list`) without a desktop session. Inside a
# container there is no X11/AT-SPI display, so the desktop backend reports
# "unavailable" on every tool call while the MCP handshake and tool listing
# still succeed — the same behaviour the server has on a headless Linux host.
#
# For real desktop control install the native binary instead; see README.md.

FROM rust:1-bookworm AS build

# xcap pulls in PipeWire/libspa (via bindgen, hence libclang), DRM/GBM, EGL and
# Wayland for screen capture, plus XCB for X11. The rest of the tree is pure Rust.
RUN apt-get update && apt-get install -y --no-install-recommends \
        pkg-config \
        clang \
        libclang-dev \
        libpipewire-0.3-dev \
        libspa-0.2-dev \
        libdrm-dev \
        libgbm-dev \
        libegl-dev \
        libwayland-dev \
        libxcb1-dev \
        libxcb-randr0-dev \
    && rm -rf /var/lib/apt/lists/*

WORKDIR /src
COPY windows-linux/ ./
RUN cargo build --release --locked

FROM debian:bookworm-slim

RUN apt-get update && apt-get install -y --no-install-recommends \
        libpipewire-0.3-0 \
        libdrm2 \
        libgbm1 \
        libegl1 \
        libwayland-client0 \
        libxcb1 \
        libxcb-randr0 \
        ca-certificates \
    && rm -rf /var/lib/apt/lists/*

COPY --from=build /src/target/release/munim-computer-use /usr/local/bin/munim-computer-use

# Browser control stays enabled so `tools/list` reports the full tool set. With
# no Chrome to pair with, the bridge socket simply never receives a connection
# and every browser_* call returns an actionable error.

ENTRYPOINT ["/usr/local/bin/munim-computer-use"]
