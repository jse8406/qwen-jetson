FROM nvcr.io/nvidia/l4t-jetpack:r36.4.0

ENV DEBIAN_FRONTEND=noninteractive

RUN apt-get update && apt-get install -y --no-install-recommends \
        curl \
        ca-certificates \
        zstd \
    && rm -rf /var/lib/apt/lists/*

# Install Ollama for Jetson:
#   1) Main ARM64 tarball supplies the binary (bin/ollama) and base GGML libs.
#      The jetpack6 tarball is a CUDA overlay, NOT standalone.
#   2) Strip the generic cuda_v12/v13 libs from the main tarball — they're
#      ~4GB of x86-oriented CUDA builds that Jetson never loads.
#   3) Overlay the jetpack6 CUDA libs (Tegra-compatible) so Ollama picks
#      them up at runtime via its plugin loader.
RUN curl -fsSL https://github.com/ollama/ollama/releases/latest/download/ollama-linux-arm64.tar.zst \
        -o /tmp/ollama.tar.zst \
    && tar --zstd -xf /tmp/ollama.tar.zst -C /usr/local \
        --exclude='lib/ollama/cuda_v12' \
        --exclude='lib/ollama/cuda_v13' \
    && rm /tmp/ollama.tar.zst \
    && curl -fsSL https://github.com/ollama/ollama/releases/latest/download/ollama-linux-arm64-jetpack6.tar.zst \
        -o /tmp/ollama-jp6.tar.zst \
    && tar --zstd -xf /tmp/ollama-jp6.tar.zst -C /usr/local \
    && rm /tmp/ollama-jp6.tar.zst \
    && /usr/local/bin/ollama --version

ENV OLLAMA_HOST=0.0.0.0:11434 \
    OLLAMA_MODELS=/root/.ollama/models \
    OLLAMA_KEEP_ALIVE=24h

COPY entrypoint.sh /entrypoint.sh
RUN chmod +x /entrypoint.sh

EXPOSE 11434

ENTRYPOINT ["/entrypoint.sh"]
