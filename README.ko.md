<div align="center">

# Claude in Phone

**노트북 WSL을 상시 가동하고, 핸드폰·태블릿·다른 PC에서 원격 접속해 작업하는 멀티 디바이스 개인 워크플로의 단일 진실원(SSOT). GitHub이 유일한 sync 경로.**

[![License: MIT](https://img.shields.io/badge/License-MIT-yellow.svg)](LICENSE)
![Platform](https://img.shields.io/badge/platform-WSL2_Ubuntu_24.04-blue)
![Remote](https://img.shields.io/badge/remote-Termius_%2B_VS_Code_Tunnel-success)

[English](README.md) · [한국어](README.ko.md)

</div>

---

## 개요

핵심 원칙 세 가지:

- 노트북에서 WSL2 Ubuntu를 24시간 켜둔다 (상시 dev host).
- 핸드폰·태블릿·다른 PC에서 두 경로로 원격 접속 — 시각 편집은 VS Code Tunnel, 모바일 터미널·Claude Code 작업은 Termius+Tailscale.
- 모든 sync는 GitHub만 경유 — USB·클라우드 드라이브·메신저 사용 금지.

본 repo는 셋업 가이드, systemd unit, 셋업 스크립트를 제공해 새 기기를 빠르게 온보딩.

## 아키텍처

```text
┌────────────────────────┐                  ┌──────────────────────┐
│  노트북 (상시 가동)     │                  │  폰 / 태블릿 / PC     │
│  WSL2 Ubuntu 24.04     │ ◄── SSH ────────►│  Termius             │
│   • sshd               │   over tailnet   │  Tailscale           │
│   • VS Code Tunnel     │ ◄── HTTPS ──────►│  vscode.dev/tunnel/  │
│   • tmux               │                  │                      │
└──────────┬─────────────┘                  └──────────┬───────────┘
           │                                           │
           └──────────────── git push/pull ────────────┘
                       GitHub (단일 sync 경로)
```

## 환경

| 항목 | 값 |
| --- | --- |
| OS | WSL2 Ubuntu 24.04 on Windows 10/11 |
| WSL 가상디스크 | 기본 위치 (시스템 드라이브 내 `.vhdx`) **또는** `wsl --import`로 이전. 어느 쪽이든 **native ext4 위에서 작업** (9P 마운트 아님) |
| 프로젝트 경로 | `~/projects/Claude_in_Phone/` |
| **작업 금지 경로** | `/mnt/*` (9P-mounted Windows NTFS — 느리고, 권한 문제, C 컴파일 깨짐) |
| 원격 저장소 | `git@github.com:<owner>/Claude_in_Phone.git` |
| 인증 | 기기마다 별도 ed25519 SSH 키 (passphrase 권장), GitHub에 각각 등록 |

> `wsl --import`로 WSL을 비-시스템 드라이브(`D:\WSL_Storage` 등)로 옮긴 경우와 기본 위치 그대로 쓰는 경우 모두 동일 — **`/mnt/*`가 아니라 native ext4 위에서 작업**.

## 작업 원칙

1. **세션 시작 = `git pull --ff-only`** — 다른 기기 커밋 먼저 받기.
2. **세션 종료 = `git add` → `commit` → `push`** — 미완성이라도 WIP 커밋. push 안 된 건 다른 기기에서 못 받음.
3. **기기 간 직접 파일 복사 금지** — sync는 오직 GitHub 경유.
4. **Auto-Yes vs 명시적 확인 구분** — 일반 명령(편집, 빌드, 통상 git, 테스트)은 즉시 실행, destructive 명령(`git push --force`, `git reset --hard`, `rm -rf` 등)은 사용자 확인 필수. 이 룰은 글로벌이므로 `~/.claude/CLAUDE.md`에 한 번만 정의 (per-repo 중복 금지).

## 원격 접속

두 경로 동시 운영. 목적에 따라 선택.

### A. VS Code Tunnel — 시각 편집

- **용도**: 코드 시각 편집, 파일 트리 검토, 마크다운 미리보기.
- **데몬**: systemd user service ([`infra/vscode-tunnel.service`](infra/vscode-tunnel.service)). `loginctl enable-linger <user>`로 WSL 부팅 시 자동 기동, 크래시 시 5초 후 재시작.
- **첫 GitHub 인증**: 서비스 최초 기동 시 journal에 device code (8자리) 출력 → `journalctl --user -u vscode-tunnel.service`로 확인 → https://github.com/login/device 에서 입력. 한 번만 하면 토큰 캐시됨.
- **접속 URL**: `https://vscode.dev/tunnel/<tunnel-name>/<workspace-path>`
- **한계**: 모바일 화면에서 VS Code UI는 터치 조작이 답답함 → 그래서 B 경로 병행.

운영 명령:
```bash
systemctl --user status vscode-tunnel.service
journalctl --user -u vscode-tunnel.service -f
```

### B. SSH over Tailscale + Termius — 모바일 터미널

가장 자주 쓰는 모바일 작업 경로. Termius 셸 안에서 `claude` 띄우는 게 기본.

**네트워크** — Tailscale mesh VPN (어디서든 P2P 암호화 접속):

| 기기 | 역할 |
| --- | --- |
| 노트북 | sshd 리스너 |
| 폰 | Termius 클라이언트 |

> **Tailscale 관리자에서 MagicDNS 켜기 권장.** Termius Host 필드에 IP 대신 hostname 사용 가능 — tailnet IP가 바뀌어도 저장된 세션이 안 깨짐.

**노트북 셋업**:
- `sudo apt install -y openssh-server` 및 `sudo systemctl enable --now ssh`
- 폰 Termius가 생성한 ED25519 공개키를 `~/.ssh/authorized_keys`에 추가
- SSH 하드닝 — `/etc/ssh/sshd_config`:
  ```
  PasswordAuthentication no
  PermitRootLogin no
  ```

**폰 셋업** (Android / iOS):
- Tailscale 앱 — 노트북과 **동일 계정** 로그인.
- Termius — Host: tailnet hostname (MagicDNS) 또는 tailnet IPv4, Port: `22`, User: 리눅스 user, Auth: SSH Key (앱 내 생성 후 공개키만 노트북에 추가).

**권장 진입 시퀀스** (`tmux`로 연결 끊김 내성 확보):
```bash
tmux new -s work          # 최초 세션
tmux attach -t work       # 재접속 시
cd ~/projects/Claude_in_Phone
claude
```

**셸 별칭** (선택, 모바일 워크플로 권장)

[`scripts/claude-tmux-aliases.sh`](scripts/claude-tmux-aliases.sh)는 `claude`를 `claude`라는 이름의 지속적 tmux 세션으로 감싸서, 외출 전 노트북에서 시작한 세션을 폰에서 SSH로 그대로 이어받게 함 — 외출 이후 뜨는 권한 prompt도 폰에서 직접 승인 가능.

각 기기에서 한 번씩 설치:
```bash
cat scripts/claude-tmux-aliases.sh >> ~/.bashrc && source ~/.bashrc
```

| 명령 | 효과 |
| --- | --- |
| `claude` | 지속적 `claude` tmux 세션 시작 (있으면 attach) |
| `cc` | 새 셸에서 빠른 재접속 (예: 폰에서 SSH 접속 후) |
| `Ctrl+b` 후 `d` | 세션 유지한 채 분리 |
| `tmux ls` | 세션 목록 |

## 새 기기 셋업

clone 직후 [`scripts/setup-new-device.sh`](scripts/setup-new-device.sh) 실행 — 2~4단계 + known_hosts 설정을 한 번에 처리. 6·7번은 의도적으로 수동.

**기본 (코드 작업 가능):**

1. WSL2 + Ubuntu 24.04 — Windows PowerShell에서 `wsl --install -d Ubuntu-24.04`. `cat /etc/wsl.conf`로 systemd 활성 확인 (`[boot]` / `systemd=true` 있어야 함). Ubuntu 24.04 기본은 켜져 있지만, `wsl --import`로 이전했거나 구버전 배포판은 직접 추가 후 `wsl --shutdown`으로 반영. 6번(VS Code Tunnel user service)과 7번(`systemctl enable --now ssh`)이 systemd 필요.
2. `sudo apt install -y git gh jq build-essential tmux`
3. 기기마다 ed25519 SSH 키 생성 → https://github.com/settings/keys 에 등록
4. `gh auth login --hostname github.com --git-protocol ssh --web`
5. `git clone git@github.com:<owner>/Claude_in_Phone.git ~/projects/Claude_in_Phone`

**원격 접속 추가 (선택):**

6. **VS Code Tunnel**:
   ```bash
   mkdir -p ~/.local/bin
   curl -sL https://update.code.visualstudio.com/latest/cli-linux-x64/stable \
     | tar -xz -C ~/.local/bin/
   mkdir -p ~/.config/systemd/user
   cp infra/vscode-tunnel.service ~/.config/systemd/user/
   systemctl --user daemon-reload
   systemctl --user enable --now vscode-tunnel.service
   sudo loginctl enable-linger "$USER"
   ```
7. **SSH over Tailscale**:
   ```bash
   sudo apt install -y openssh-server
   sudo systemctl enable --now ssh
   curl -fsSL https://tailscale.com/install.sh | sudo sh
   sudo tailscale up
   # 그 다음 폰 Termius 공개키를 ~/.ssh/authorized_keys에 추가
   ```

## Claude Code 사용 시 참고

- 폰 접속 비중이 크니 응답은 짧게, 긴 로그는 요약.
- 경로는 절대 경로 우선 — Bash 도구는 호출 간 cwd를 유지하지 않음.
- 권한 모드: `bypassPermissions` 기본 (`~/.claude/settings.json`). Shift+Tab으로 토글.

## 트러블슈팅

### 폰과 노트북에 같은 화면이 보이고, 입력이 양쪽에서 다 들어감

설계상 그렇습니다. 노트북과 폰이 같은 `claude` tmux 세션에 동시에 attach 되어 있으면 **모든 키 입력이 양쪽 클라이언트 간 공유**됩니다. 이게 본 워크플로의 핵심 — 노트북에서 작업 시작 → 그대로 두고 외출 → 폰에서 컨텍스트 손실 없이 이어서 작업, 이 흐름을 가능케 하는 메커니즘입니다.

부작용: 두 클라이언트가 동시 attach 되어 있으면 tmux 가 화면을 **둘 중 더 작은 쪽** (보통 폰) 크기로 강제 축소시켜서 노트북 화면이 답답해집니다. 한 쪽만 단독으로 attach 하려면 다른 쪽을 강제로 떼어내면서 들어가야 합니다:

```bash
tmux attach -d -t claude   # -d 옵션 = 기존 attach된 다른 클라이언트를 detach 시킴
```

폰에서 reattach 할 때 매번 이 동작을 기본으로 하고 싶으면 [`scripts/claude-tmux-aliases.sh`](scripts/claude-tmux-aliases.sh) 의 `cc` 별칭을 다음으로 교체:

```bash
alias cc='tmux attach -d -t claude'
```

또는 안 쓰는 쪽에서 매번 detach (`Ctrl+B` 누른 뒤 손 떼고 `d`) 해두는 방법도 있음.

### Claude Code 입력 박스가 멈춤 — Enter 누르면 줄바꿈만, 화살표/Ctrl 키가 `^[[A` / `^B` 로 글자로 찍힘

증상: 타이핑은 입력창에 보이는데 Enter 가 줄바꿈만 추가, `Ctrl+B` 가 `^B` 로 찍힘, 화살표 키가 `^[[A` / `^[[B` 로 남음. Claude Code 프로세스가 hang 되어 키 입력 파서가 escape sequence 를 더 이상 해석하지 못하는 상태. `/usage` 같은 인터랙티브 dialog 가 dismiss 후 raw 입력 모드 복구에 실패할 때 자주 발생.

세션 내부 키로는 복구 불가 — **밖에서** 죽여야 합니다. 별도 터미널 (랩탑이면 Windows Terminal 새 탭, 폰이면 새 SSH 세션) 을 열어서:

```bash
tmux ls                          # "claude" 세션이 살아있는지 확인
tmux kill-session -t claude
claude                           # 별칭 통해 깔끔하게 재시작
```

`tmux ls` 에 아무것도 없거나 세션 이름이 다르면 프로세스를 직접:

```bash
pkill -9 -f "claude code"
```

다른 클라이언트 (attach 중이던 쪽) 는 세션이 사라지면 알아서 종료됩니다. 이후 `claude` / `cc` 로 재접속.

### 폰 (Termius): Enter 가 제출 안 됨, 줄바꿈만 추가됨

모바일 키보드가 TUI 가 기대하는 `\r` (carriage return) 대신 `\n` (line feed) 을 보내는 경우가 있어, Claude Code 가 Enter 를 "줄바꿈 삽입" 으로만 처리.

- **즉시 회피**: Termius 키바 (키보드 위쪽 단축키 줄) 에서 **`Ctrl`** 한 번 탭 → 일반 키보드에서 **`M`** 탭. `Ctrl+M` 이 `\r` 을 직접 보내서 제출됨.
- **영구 해결**: Termius → 호스트 설정 → **Terminal** → **Return key** 를 `CR` (`\r`) 로 변경 (`LF` 나 Auto 가 아니어야 함).
- **한글 IME** (Gboard 한글, 삼성 키보드 한글 등) 가 Termius 설정과 무관하게 터미널 앱에서 Enter 를 가로채는 경우가 잦음. 명령은 영어 키보드 모드로 입력하고 한글 내용은 클립보드/Termius snippet 으로 붙여넣기 권장.

## 보안 하드닝

`bypassPermissions` + 모바일 조합은 destructive 명령의 의도치 않은 실행 위험이 가장 큰 환경. 글로벌 `~/.claude/settings.json`에 hard-block을 박아둠 — `deny` 패턴은 bypass 모드에서도 우회 불가:

```jsonc
{
  "permissions": {
    "defaultMode": "bypassPermissions",
    "deny": [
      "Bash(git push --force*)",
      "Bash(git push -f*)",
      "Bash(git reset --hard*)",
      "Bash(rm -rf*)",
      "Bash(:>*)"
    ]
  }
}
```

- `defaultMode: "bypassPermissions"`는 새 세션부터 명령마다 묻지 않음 (Termius 모바일 워크플로와 정합). 위 `deny` 패턴은 모드 무관 hard-block.
- `defaultMode`는 에이전트가 `settings.json`을 편집하려 들 때 self-modification으로 분류기에 거부될 수 있음 — 본인 셋업 시 `/config` 또는 직접 편집으로 진행.

추가 위생 관리:

- 각 기기 SSH 키에 passphrase 설정 (`ssh-keygen -t ed25519` 생성 시 입력).
- 기기마다 별도 GitHub SSH 키 → 분실 시 해당 키만 revoke.
- GitHub recovery code는 디바이스 밖에 (인쇄 또는 별도 password manager).

## 백업 전략

단일 장애점 인지:

- **GitHub** — 모든 sync 경로. 계정 잠금 = 전 디바이스 sync 마비. recovery code 인쇄 보관, 백업 PAT를 오프라인에 별도 보관.
- **WSL 가상디스크 (`.vhdx`)** — 노트북 로컬에만 존재. 디스크 고장 = 미푸시 작업 손실. 룰 2를 엄수 (세션 종료 시 무조건 push). 추가로 `.vhdx`가 있는 폴더(`C:\Users\<user>\AppData\Local\Packages\CanonicalGroupLimited.*\LocalState\`)를 OneDrive·외장하드에 주기 백업.
- **SSH 키** — per-device. 분실 시 해당 키만 revoke. 키를 기기 간 공유 금지.

## Repository 구조

```
.
├── README.md                    # 영어 버전
├── README.ko.md                 # 이 문서 (한국어)
├── CLAUDE.md                    # Claude Code 컨텍스트 (slim)
├── LICENSE                      # MIT
├── infra/
│   └── vscode-tunnel.service    # systemd user unit
└── scripts/
    ├── claude-tmux-aliases.sh   # bash 별칭 — claude를 지속적 tmux 세션으로 감싸기
    └── setup-new-device.sh      # 새 기기 base 셋업 자동화
```

## License

MIT. [LICENSE](LICENSE) 참조.
