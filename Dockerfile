FROM nvcr.io/nvidia/l4t-jetpack:r36.4.0

ENV DEBIAN_FRONTEND=noninteractive

RUN apt-get update && apt-get install -y --no-install-recommends \
        curl \
        ca-certificates \
        zstd \
    && rm -rf /var/lib/apt/lists/*

# Install the Jetson-specific Ollama build (JetPack 6, includes CUDA libs
# built for Tegra). Asset format is .tar.zst, so we need zstd to extract.
RUN curl -fsSL https://github.com/ollama/ollama/releases/latest/download/ollama-linux-arm64-jetpack6.tar.zst \
        -o /tmp/ollama.tar.zst \
    && tar --zstd -xf /tmp/ollama.tar.zst -C /usr/local \
    && rm /tmp/ollama.tar.zst \
    && /usr/local/bin/ollama --version

ENV OLLAMA_HOST=0.0.0.0:11434 \
    OLLAMA_MODELS=/root/.ollama/models \
    OLLAMA_KEEP_ALIVE=24h

COPY entrypoint.sh /entrypoint.sh
RUN chmod +x /entrypoint.sh

EXPOSE 11434

ENTRYPOINT ["/entrypoint.sh"]
