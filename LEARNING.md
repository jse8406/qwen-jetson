# 학습 노트 — Qwen on Jetson 프로젝트를 진행하면서 등장한 개념들

이 문서는 **처음 보는 용어가 쏟아져서 뭐가 뭔지 모르겠다** 고 느꼈을 때 돌아와서 읽는 문서입니다.
"왜 이렇게 해야 했는지"를 중심으로 정리했어요.

---

## 0. 이 프로젝트가 하려는 것 (한 줄 요약)

> **내 PC에서 작성한 도커 설정**을 **GitHub를 통해 Jetson에 전달**하고, **Jetson에서 도커 컨테이너로 Qwen 2.5 3B 모델을 구동**하기.

```
[로컬 PC(Windows)]          [GitHub]            [Jetson Orin Nano]
  코드 작성       push   →   원격 저장소  →  pull    도커로 실행
  git commit                (jse8406/qwen-jetson)   docker compose up
```

왜 이렇게 할까?
- Jetson에서 직접 vim으로 편집해도 되지만, **코드 변경 이력 관리**와 **PC와 Jetson 양쪽에서 편집 가능** 하려면 GitHub를 거치는 게 표준.
- 모델 파일(GB 단위)은 절대 GitHub에 올리지 않음 — 그래서 `.gitignore`로 제외.

---

## 1. Docker 를 왜 쓰는가

Jetson에 직접 Ollama를 깔면:
- JetPack 버전, CUDA 버전, 시스템 라이브러리 꼬임 → 언젠가 부팅 꼬이면 전부 다시 세팅
- 다른 프로젝트와 의존성 충돌 가능

Docker는 **"앱을 격리된 상자(컨테이너)에 담아서 실행"** 합니다.
- 호스트(Jetson 본체)는 깨끗하게 유지
- 컨테이너 날려도 호스트엔 흔적 안 남음
- 다른 Jetson에서도 동일하게 재현 가능

### Docker 핵심 용어 3개

| 용어 | 비유 | 이 프로젝트에서 |
|---|---|---|
| **이미지 (image)** | 붕어빵 틀 | `Dockerfile`로 구워낸 `qwen-jetson:latest` |
| **컨테이너 (container)** | 붕어빵 (틀로 찍어낸 결과물) | 실제로 실행 중인 `qwen-jetson` 프로세스 |
| **볼륨 (volume)** | 컨테이너에 붙이는 외장하드 | 모델 파일을 저장하는 `~/ollama-data` |

컨테이너는 지우면 안에 뭐가 있었든 사라지는데, **볼륨**은 호스트에 남습니다. 그래서 모델 파일처럼 한 번 받으면 보존하고 싶은 건 볼륨에 둡니다.

### Dockerfile / docker-compose.yml 의 역할

- **Dockerfile**: 이미지를 **어떻게 만들지** 적은 레시피. 한 줄씩 리눅스 명령어로 "베이스 이미지 가져와 → 패키지 깔아 → 스크립트 복사해" 를 기술.
- **docker-compose.yml**: **실행 시 옵션**(포트, 볼륨, 환경변수, GPU 런타임 등)을 기술. `docker run ...` 커맨드를 길게 쓰는 대신 yaml 파일 하나로 관리.

`docker compose up -d --build`:
- `-d`: detached(백그라운드)
- `--build`: Dockerfile 변경 시 이미지 다시 빌드

---

## 2. NVMe / 마운트 / 파일시스템 — 왜 `/mnt/nvme` 얘기가 나왔나

### 배경

Jetson Orin Nano는 보통 두 가지 저장소를 가질 수 있어요:
1. **SD카드 / eMMC** — 기본 내장, 느리고 용량 작음
2. **NVMe SSD** — M.2 슬롯에 꽂는 SSD, 빠르고 큼

LLM 모델 파일은 크기 때문에(2GB~수십 GB), 가능하면 **빠르고 큰 NVMe에 두는 게 권장됩니다.**
그래서 원래 가이드에선 `/mnt/nvme/ollama` 경로를 예시로 썼어요.

### 당신의 Jetson은 어떤 상태였나

`lsblk -f` 결과에 이렇게 나왔죠:

```
nvme0n1p1   ext4   ...   /
```

이 줄의 의미:
- `nvme0n1p1` = NVMe SSD의 첫 번째 파티션
- `/` = **루트 파일시스템** 으로 마운트됨

즉 **운영체제 자체가 NVMe 위에서 돌고 있다**는 뜻. 홈 디렉터리(`/home/jse`)도 당연히 NVMe에 있고, 233GB 중 190GB가 비어 있습니다.

별도의 `/mnt/nvme` 마운트 지점은 존재하지 않아요.

### "마운트" 가 뭔데?

리눅스에선 디스크를 그냥 꽂는다고 쓸 수 있는 게 아니라, **파일시스템의 특정 디렉터리에 연결** 해줘야 접근 가능합니다. 그 연결 작업이 **마운트(mount)** 예요.

- 윈도우: C 드라이브, D 드라이브처럼 드라이브 문자로 구분
- 리눅스: 모든 게 `/` 아래 트리 구조. 디스크는 `/`, `/home`, `/mnt/foo` 등 어느 디렉터리에 "연결" 된 형태로 나타남

**당신의 Jetson**은 NVMe 한 개만 꽂혀 있고 그게 `/`(루트)에 마운트됐습니다. 따라서 `/mnt/nvme`를 만들 필요도 없고, 그냥 홈 디렉터리(`~/ollama-data` = `/home/jse/ollama-data`)에 저장하면 이미 NVMe 위에 저장되는 겁니다.

### 그래서 `.env` 파일을 왜 쓰나?

`docker-compose.yml`에 이런 줄이 있어요:

```yaml
volumes:
  - ${OLLAMA_DATA_PATH:-./ollama-data}:/root/.ollama
```

이 문법은:
- `${OLLAMA_DATA_PATH:-./ollama-data}` = 환경 변수 `OLLAMA_DATA_PATH`가 있으면 그 값, 없으면 `./ollama-data` 사용
- `:` 왼쪽 = 호스트(Jetson) 경로
- `:` 오른쪽 = 컨테이너 안 경로 (Ollama가 모델 저장하는 기본 경로)

`.env` 파일은 `docker compose` 명령이 자동으로 읽어서 환경변수를 채워줍니다. 그래서:

```bash
# .env 내용
OLLAMA_DATA_PATH=/home/jse/ollama-data
```

이렇게 해두면 호스트의 `/home/jse/ollama-data` ↔ 컨테이너 안의 `/root/.ollama` 가 연결됩니다.

---

## 3. heredoc 과 들여쓰기 실수

처음 `.env` 만들려다 프롬프트가 `>` 로 멈춰서 안 끝났던 그 상황.

### 원래 문법

```bash
cat > .env << 'EOF'
OLLAMA_DATA_PATH=/home/jse/ollama-data
EOF
```

이게 bash의 **heredoc(here-document)** 문법입니다.
- `<< 'EOF'` ~ `EOF` 사이의 내용을 **표준입력**으로 `cat` 에 넘겨줌
- `>`로 리다이렉션돼서 `.env` 파일로 저장됨

### 왜 멈췄나

bash는 **종료 마커(`EOF`)가 줄의 맨 앞(column 0)에 정확히 있을 때만** heredoc 끝으로 인식합니다.
당신이 붙여넣을 때 어떤 이유로 `EOF` 앞에 공백이 붙어서 ` EOF` 로 들어가버렸고, bash는 "아직 안 끝났네" 하고 계속 입력 대기(`>`)에 빠진 거예요.

### 더 안전한 대안

한 줄짜리 간단한 파일이면 heredoc 말고 echo가 편합니다:

```bash
echo 'OLLAMA_DATA_PATH=/home/jse/ollama-data' > .env
```

- `>` = 덮어쓰기
- `>>` = 이어쓰기

---

## 4. Linux 사용자 그룹 — 왜 `docker` 그룹에 넣어야 하나

### 에러 메시지 복습

```
permission denied while trying to connect to the Docker daemon socket
at unix:///var/run/docker.sock
```

### 무슨 일인가

Docker는 백그라운드에서 돌아가는 **데몬(docker daemon)** 이 있고, `docker` 명령은 유닉스 소켓 파일 `/var/run/docker.sock` 을 통해 그 데몬과 통신합니다.

이 소켓 파일의 권한은 보통:

```
srw-rw---- 1 root docker 0 ... /var/run/docker.sock
```

- 소유자: `root`
- 그룹: `docker`
- `root` 또는 **`docker` 그룹 멤버** 만 읽고 쓸 수 있음

당신의 `jse` 사용자는 `docker` 그룹에 속하지 않아서 소켓을 못 열었고, 그래서 "permission denied" 가 난 겁니다.

### 해결 — `usermod -aG`

```bash
sudo usermod -aG docker $USER
```

- `usermod`: 사용자 수정
- `-a`: append(추가) — 빼먹으면 기존 그룹 다 날아가니까 **반드시** 붙여야 함
- `-G docker`: `docker` 그룹에
- `$USER`: 현재 사용자 이름 (여기선 `jse`)

### 왜 "로그아웃 후 재접속" 이 필요하나

리눅스의 그룹 정보는 **로그인 시점에 읽혀서 그 세션 동안 유지**됩니다.
지금 열려 있는 SSH 세션은 "jse는 어떤 그룹들에 속함" 이라는 스냅샷을 이미 갖고 있어서, `usermod` 로 그룹을 바꿔도 **그 세션엔 반영 안 됨**.

새 세션을 열어야(SSH 재접속, 재부팅, `newgrp docker`) 변경된 그룹 목록이 로드됩니다.

### 확인

```bash
groups        # 출력에 'docker' 포함?
docker ps     # sudo 없이 됨?
```

둘 다 OK면 준비 완료.

---

## 5. `sudo docker` 는 안 돼?

되긴 돼요. 하지만:
1. 매번 `sudo` 쳐야 함 (귀찮음)
2. `sudo docker` 로 만든 컨테이너의 **볼륨 파일이 root 소유** 로 생김 → 나중에 `~/ollama-data` 안 파일 만지려면 또 `sudo` 필요
3. `docker compose` 는 `.env` 파일 읽기 등에서 일반 사용자 컨텍스트가 편함

그래서 정공법(그룹 추가 + 재접속)이 장기적으로 편합니다.

---

## 6. 지금까지 한 일 타임라인

1. **로컬에서 프로젝트 파일 작성** (`C:\Users\jse\Desktop\vscode\qwen_container\`)
   - `Dockerfile` — `l4t-jetpack:r36.4.0` 이미지 위에 Ollama 설치
   - `entrypoint.sh` — 컨테이너 시작 시 `ollama serve` → 모델 자동 pull
   - `docker-compose.yml` — 실행 옵션 (포트, 볼륨, nvidia runtime)
   - `.gitignore` — 모델 파일, `.env`, 로그 등 제외
   - `.gitattributes` — 줄바꿈 LF 강제 (아래 7번 참고)
   - `README.md` — 사용 가이드

2. **GitHub에 push**
   - `git init -b main` → 초기화 (기본 브랜치 `main`)
   - `git add . && git commit` → 첫 커밋
   - `gh repo create jse8406/qwen-jetson --public --source=. --push` → GitHub에 repo 생성 + push 를 한 번에

3. **Jetson에서 clone & 셋업**
   - `git clone ...` → repo 내려받음
   - `.env` 만들어서 모델 저장 경로 지정
   - `docker compose up -d --build` → 빌드 + 실행

---

## 7. `.gitattributes` 와 줄바꿈 (LF vs CRLF)

### 문제

- **Windows**: 줄바꿈이 `\r\n` (CRLF)
- **Linux/Mac**: 줄바꿈이 `\n` (LF)

Windows에서 만든 `entrypoint.sh` 가 CRLF 로 저장돼 Jetson에 전달되면, 리눅스는 첫 줄의 `#!/usr/bin/env bash\r` 를 명령으로 인식 못 해서 **`: No such file or directory`** 같은 이상한 에러가 납니다.

### 해결

프로젝트 루트의 `.gitattributes` 에 이렇게 썼어요:

```
* text=auto eol=lf
*.sh       text eol=lf
Dockerfile text eol=lf
*.yml      text eol=lf
```

이건 git 에게 "이 프로젝트의 텍스트 파일은 **저장소 안에서도 LF, 체크아웃할 때도 LF**" 라고 명시한 것. 덕분에 Windows에서 푸시해도 Jetson에선 LF로 내려와 정상 실행됩니다.

### 파일 권한(executable bit)

```bash
git update-index --chmod=+x entrypoint.sh
```

리눅스에선 스크립트를 실행하려면 **실행 권한**(chmod +x)이 필요. Windows에선 이런 개념이 없어서 git이 혼자서는 실행권한을 못 붙이므로, 명시적으로 위 명령으로 설정해서 커밋에 포함시킨 겁니다.

git 인덱스에서 `100755` 가 보이면 실행권한 포함, `100644` 는 일반 파일.

---

## 8. 주요 개념 치트시트

| 개념 | 한 줄 요약 |
|---|---|
| **Docker image** | 컨테이너의 틀. Dockerfile로 빌드 |
| **Docker container** | 이미지를 실행한 결과물. 격리된 프로세스 |
| **Docker volume** | 호스트 디렉터리를 컨테이너에 연결. 데이터 영속화 |
| **NVIDIA runtime** | GPU를 컨테이너 안에서 쓸 수 있게 해주는 런타임. Jetson은 기본 설치됨 |
| **Ollama** | LLM 실행 서버. `ollama serve` 로 HTTP API(11434 포트) 제공 |
| **마운트 (mount)** | 디스크를 파일시스템 트리에 연결하는 작업 |
| **NVMe** | M.2 슬롯 SSD. Jetson에서 가장 빠른 저장소 |
| **사용자 그룹** | 파일/소켓 접근 권한 단위. `docker` 그룹에 속하면 `docker` 명령 sudo 없이 가능 |
| **heredoc** | `cat << 'EOF' ... EOF` 로 여러 줄 텍스트를 명령에 넘김. 종료 마커는 맨 앞에 |
| **환경변수** | 셸/프로세스에 전달되는 설정값. `$VAR` 로 참조, `export VAR=...` 로 설정 |
| **.env 파일** | `docker compose` 가 자동으로 읽어 컴포즈 파일의 `${VAR}` 치환에 쓰는 파일 |
| **CRLF vs LF** | 줄바꿈 문자 차이. 크로스 플랫폼 프로젝트는 `.gitattributes` 로 LF 강제 권장 |
| **실행 권한** | 리눅스에서 `chmod +x`. git에선 `update-index --chmod=+x` |

---

## 9. 자주 막힐만한 에러 → 대응

| 에러 메시지 | 원인 | 해결 |
|---|---|---|
| `permission denied ... docker.sock` | `docker` 그룹 미가입 | `sudo usermod -aG docker $USER` → 재접속 |
| `mkdir: 허가 거부` | 해당 상위 디렉터리가 root 소유 | `sudo mkdir` or 홈 디렉터리로 변경 |
| heredoc에서 `>` 프롬프트가 안 끝남 | 종료 마커 앞에 공백 | Ctrl+C 후, `EOF`를 줄 맨 앞에 붙여 재실행 |
| `/usr/bin/env: bash\r` | Windows CRLF 가 스크립트에 섞임 | `.gitattributes` + `dos2unix` |
| `could not select device driver "nvidia"` | NVIDIA Container Toolkit 미설치 | `sudo apt install nvidia-container-toolkit` |
| 모델이 CPU로만 돔 | Jetson CUDA 미탐지 | `docker exec qwen-jetson ollama ps` 의 PROCESSOR 열 확인, `tegrastats` 로 교차 확인 |

---

## 10. 다음 단계

1. `sudo usermod -aG docker $USER` 실행 후 **SSH 재접속**
2. `groups` 에 `docker` 있는지 확인
3. `cd ~/qwen-jetson && docker compose up -d --build`
4. `docker compose logs -f` 로 `[entrypoint] Ready.` 확인
5. `curl http://localhost:11434/api/tags` 로 API 테스트
6. 추론 테스트:
   ```bash
   curl http://localhost:11434/api/generate -d '{
     "model": "qwen2.5:3b",
     "prompt": "안녕",
     "stream": false
   }'
   ```

---

## 참고 링크

- Docker 공식 튜토리얼: https://docs.docker.com/get-started/
- Ollama: https://ollama.com/
- Jetson Containers (jetson-containers): https://github.com/dusty-nv/jetson-containers
- 리눅스 파일시스템/마운트 개념: `man mount`, `man fstab`
