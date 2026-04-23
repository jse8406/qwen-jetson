"""Minimal CLI chat client for the Jetson Ollama server.

사용법:
    python chat.py                       # 기본 (qwen:jetson @ jse-desktop)
    set OLLAMA_MODEL=qwen2.5:1.5b && python chat.py
    set OLLAMA_HOST=http://192.168.1.50:11434 && python chat.py

종료: 빈 줄에서 Enter, 또는 Ctrl+C.
"""
import json
import os
import sys
import urllib.error
import urllib.request

HOST = os.environ.get("OLLAMA_HOST", "http://jse-desktop:11434")
MODEL = os.environ.get("OLLAMA_MODEL", "qwen:jetson")


def chat_stream(history):
    """Send chat history and stream the assistant reply to stdout."""
    payload = json.dumps(
        {"model": MODEL, "messages": history, "stream": True}
    ).encode("utf-8")
    req = urllib.request.Request(
        f"{HOST}/api/chat",
        data=payload,
        headers={"Content-Type": "application/json"},
    )
    chunks = []
    with urllib.request.urlopen(req) as resp:
        for line in resp:
            if not line.strip():
                continue
            msg = json.loads(line)
            piece = msg.get("message", {}).get("content", "")
            if piece:
                sys.stdout.write(piece)
                sys.stdout.flush()
                chunks.append(piece)
            if msg.get("done"):
                break
    print()
    return "".join(chunks)


def main():
    # UTF-8 강제 (Windows 한국어 cp949 이슈 회피)
    sys.stdout.reconfigure(encoding="utf-8")
    try:
        sys.stdin.reconfigure(encoding="utf-8")
    except Exception:
        pass  # stdin이 파이프가 아닌 콘솔이면 이미 UTF-8일 수 있음
    print(f"host : {HOST}")
    print(f"model: {MODEL}")
    print("-" * 60)
    print("질문을 입력하세요. 빈 줄 Enter 또는 Ctrl+C 로 종료.")

    history = []
    while True:
        try:
            user = input("\n너  > ").strip()
        except (EOFError, KeyboardInterrupt):
            break
        if not user:
            break

        history.append({"role": "user", "content": user})
        print("AI  > ", end="", flush=True)
        try:
            reply = chat_stream(history)
        except urllib.error.URLError as e:
            print(f"\n[네트워크 오류] {e}")
            history.pop()
            continue
        except KeyboardInterrupt:
            print("\n[중단됨]")
            history.pop()
            continue
        history.append({"role": "assistant", "content": reply})

    print("\n종료.")


if __name__ == "__main__":
    main()
