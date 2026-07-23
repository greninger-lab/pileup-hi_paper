# ── Stage 1: build pileup-hi ───────────────────────────────────────────────────
FROM --platform=linux/amd64 rust:slim AS builder

RUN apt-get update && apt-get install -y \
    pkg-config \
    libssl-dev \
    clang \
    libclang-dev \
    libbz2-dev \
    liblzma-dev \
    libcurl4-openssl-dev \
    libdeflate-dev \
    libncurses-dev \
    zlib1g-dev \
    wget bzip2 make gcc autoconf perl \
    && rm -rf /var/lib/apt/lists/*

ARG HTSLIB_VERSION=1.23
RUN wget -q https://github.com/samtools/htslib/releases/download/${HTSLIB_VERSION}/htslib-${HTSLIB_VERSION}.tar.bz2 \
    && tar -xjf htslib-${HTSLIB_VERSION}.tar.bz2 \
    && cd htslib-${HTSLIB_VERSION} \
    && ./configure --prefix=/usr/local --enable-libcurl \
    && make -j"$(nproc)" && make install \
    && cd .. && rm -rf htslib-${HTSLIB_VERSION}*

ENV PKG_CONFIG_PATH=/usr/local/lib/pkgconfig
ENV LIBRARY_PATH=/usr/local/lib
ENV LD_LIBRARY_PATH=/usr/local/lib

WORKDIR /build

COPY pileup-hi/Cargo.toml pileup-hi/Cargo.lock ./
COPY pileup-hi/build.rs ./build.rs
COPY pileup-hi/src/overlap_wrapper.c ./src/overlap_wrapper.c
RUN mkdir -p src && echo "fn main() {}" > src/main.rs \
    && cargo build --release

# ── Real source ───────────────────────────────────────────────────────────────
COPY pileup-hi/src ./src
RUN touch src/main.rs && cargo build --release

# ── Stage 2: runtime ──────────────────────────────────────────────────────────
FROM --platform=linux/amd64 ubuntu:24.04

ARG SAMTOOLS_VERSION=1.23
ENV DEBIAN_FRONTEND=noninteractive

# Runtime libs needed by samtools + general utilities
RUN apt-get update && apt-get install -y \
    wget \
    bzip2 \
    ca-certificates \
    libncurses6 \
    libbz2-1.0 \
    parallel \
    liblzma5 \
    libcurl4 \
    libdeflate0 \
    zlib1g \
    && rm -rf /var/lib/apt/lists/*

# ── samtools 1.23 ─────────────────────────────────────────────────────────────
RUN wget -q https://github.com/samtools/samtools/releases/download/${SAMTOOLS_VERSION}/samtools-${SAMTOOLS_VERSION}.tar.bz2 \
    && tar -xjf samtools-${SAMTOOLS_VERSION}.tar.bz2 \
    && cd samtools-${SAMTOOLS_VERSION} \
    && apt-get update && apt-get install -y \
        gcc make \
        libncurses-dev \
        libbz2-dev \
        liblzma-dev \
        libcurl4-openssl-dev \
        libdeflate-dev \
        zlib1g-dev \
    && ./configure --prefix=/usr/local \
    && make -j"$(nproc)" \
    && make install \
    && cd .. && rm -rf samtools-${SAMTOOLS_VERSION}* \
    && apt-get purge -y gcc make libncurses-dev libbz2-dev liblzma-dev libcurl4-openssl-dev libdeflate-dev zlib1g-dev \
    && apt-get autoremove -y \
    && rm -rf /var/lib/apt/lists/*

# ── b3sum (pre-built binary) ──────────────────────────────────────────────────
RUN wget -q https://github.com/BLAKE3-team/BLAKE3/releases/download/1.8.3/b3sum_linux_x64_bin \
    && mv b3sum_linux_x64_bin /usr/local/bin/b3sum \
    && chmod +x /usr/local/bin/b3sum

# ── pileup-hi (from builder stage) ────────────────────────────────────────────
COPY --from=builder /build/target/release/pileuphi /usr/local/bin/
COPY --from=builder /usr/local/lib/libhts.so* /usr/local/lib/
RUN ldconfig

# ── para_mpileup.sh ───────────────────────────────────────────────────────────
COPY para_mpileup.sh /usr/local/bin/para_mpileup.sh
RUN chmod +x /usr/local/bin/para_mpileup.sh

# Sanity check all tools are present and executable
RUN samtools --version
# RUN pileuphi --version
RUN b3sum --version

WORKDIR /tmp
