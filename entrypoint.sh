#!/usr/bin/env bash
set -euo pipefail

MODEL="${QWEN_MODEL:-qwen2.5:3b}"
HOST="${OLLAMA_HOST:-0.0.0.0:11434}"

echo "[entrypoint] Starting ollama serve..."
ollama serve &
SERVE_PID=$!

echo "[entrypoint] Waiting for Ollama API on 127.0.0.1:11434 ..."
for i in $(seq 1 60); do
    if curl -sf "http://127.0.0.1:11434/api/tags" >/dev/null 2>&1; then
        echo "[entrypoint] Ollama is up."
        break
    fi
    if [ "$i" -eq 60 ]; then
        echo "[entrypoint] ERROR: Ollama did not start within 60s" >&2
        kill "${SERVE_PID}" 2>/dev/null || true
        exit 1
    fi
    sleep 1
done

if ollama list 2>/dev/null | awk 'NR>1 {print $1}' | grep -qx "${MODEL}"; then
    echo "[entrypoint] Model '${MODEL}' already present. Skipping pull."
else
    echo "[entrypoint] Pulling model '${MODEL}' (first run may take several minutes)..."
    ollama pull "${MODEL}"
    echo "[entrypoint] Pull complete."
fi

echo "[entrypoint] Ready. Serving on ${HOST} | model=${MODEL}"
wait "${SERVE_PID}"
