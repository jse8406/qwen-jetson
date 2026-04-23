# qwen-jetson

Jetson Orin Nano(JetPack 6 / L4T R36.4.x)에서 **Qwen 2.5 3B** 를 **Ollama** 로 GPU 가속 구동하는 Docker 구성.

- Base image: `nvcr.io/nvidia/l4t-jetpack:r36.4.0`
- Runtime: `nvidia` (Jetson CUDA 자동 감지)
- API: `http://<jetson-ip>:11434` (OpenAI/Ollama 호환)
- 컨테이너 기동 시 `qwen2.5:3b` 자동 pull (이미 받아뒀으면 스킵)

---

## 요구사항 (Jetson 쪽)

- JetPack 6 (L4T R36.4.x) 설치된 Jetson Orin Nano
- Docker + NVIDIA Container Runtime (JetPack 기본 포함)
  - `docker info | grep -i runtime` 결과에 `nvidia` 가 있어야 함
- NVMe 권장 (모델 저장 경로)

---

## Jetson에서 최초 실행

```bash
git clone https://github.com/<your-id>/qwen-jetson.git
cd qwen-jetson

# 모델 저장 경로 설정 (NVMe 권장)
cat > .env << 'EOF'
OLLAMA_DATA_PATH=/mnt/nvme/ollama
EOF

mkdir -p /mnt/nvme/ollama

docker compose up -d --build
docker compose logs -f   # 모델 다운로드 진행 상황 확인
```

로그에 `[entrypoint] Ready.` 가 뜨면 준비 완료.

---

## 동작 확인

```bash
# 모델 목록
curl http://localhost:11434/api/tags

# 간단 추론
curl http://localhost:11434/api/generate -d '{
  "model": "qwen2.5:3b",
  "prompt": "안녕, 너는 누구야?",
  "stream": false
}'
```

GPU 사용 여부는 Jetson에서:

```bash
sudo tegrastats
```

추론 중 `GR3D_FREQ` 가 올라가면 GPU 가속 OK.

---

## 업데이트 워크플로우

**로컬 PC**

```bash
git add .
git commit -m "<change>"
git push
```

**Jetson**

```bash
cd ~/qwen-jetson
git pull
docker compose up -d --build
```

---

## 환경 변수

| 변수 | 기본값 | 설명 |
|---|---|---|
| `OLLAMA_DATA_PATH` | `./ollama-data` | 호스트의 모델 저장 경로 (NVMe 권장) |
| `QWEN_MODEL` | `qwen2.5:3b` | 자동 pull 할 모델 태그 (entrypoint가 사용) |

모델을 바꾸려면 `docker-compose.yml` 의 `environment` 에 `QWEN_MODEL=qwen2.5:7b` 같은 식으로 추가.

---

## 파일 구성

```
qwen-jetson/
├── Dockerfile          # l4t-jetpack + Ollama 설치
├── entrypoint.sh       # serve → health check → 자동 pull → foreground
├── docker-compose.yml  # nvidia runtime + 볼륨 + 포트
├── .gitignore          # 모델/로그/env 제외
└── README.md
```

---

## 문제 해결

- **`could not select device driver "nvidia"`**
  NVIDIA Container Runtime 미설치 또는 미등록. `sudo apt install nvidia-container-toolkit` 후 Docker 재시작.
- **모델 pull 이 너무 느림 / 중간에 끊김**
  네트워크 확인 후 `docker compose restart`. entrypoint가 이미 받은 모델은 건너뜀.
- **CPU로만 도는 것 같음**
  `docker exec -it qwen-jetson ollama ps` 실행 → `PROCESSOR` 열에 `GPU` 표시 확인. `tegrastats` 로 교차 확인.
