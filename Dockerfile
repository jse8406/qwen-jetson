FROM nvcr.io/nvidia/l4t-jetpack:r36.4.0

ENV DEBIAN_FRONTEND=noninteractive

RUN apt-get update && apt-get install -y --no-install-recommends \
        curl \
        ca-certificates \
    && rm -rf /var/lib/apt/lists/*

# Install Ollama ARM64 binary directly.
# We avoid `install.sh` because it runs `lspci`/`lshw` for GPU detection
# (not present in l4t-jetpack and useless on Jetson's SoC GPU anyway).
RUN curl -fsSL https://github.com/ollama/ollama/releases/latest/download/ollama-linux-arm64.tgz \
        -o /tmp/ollama.tgz \
    && tar -xzf /tmp/ollama.tgz -C /usr/local \
    && rm /tmp/ollama.tgz \
    && /usr/local/bin/ollama --version

ENV OLLAMA_HOST=0.0.0.0:11434 \
    OLLAMA_MODELS=/root/.ollama/models \
    OLLAMA_KEEP_ALIVE=24h

COPY entrypoint.sh /entrypoint.sh
RUN chmod +x /entrypoint.sh

EXPOSE 11434

ENTRYPOINT ["/entrypoint.sh"]
