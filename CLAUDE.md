# Claude_in_Phone

Sweet-Butters의 다중-기기 개발 환경 베이스 repo. 노트북 WSL을 상시 가동해두고, 핸드폰이나 다른 기기에서 VS Code `code tunnel`로 원격 접속해 작업하는 워크플로의 단일 진실원(single source of truth).

## 환경

- **OS**: WSL2 Ubuntu 24.04 (Windows 11 노트북). 배포판은 `wsl --import`로 `D:\WSL_Storage`에 옮겨져 있어 홈 디렉터리(`/home/sweetbutters/...`)가 물리적으로 D 드라이브 위에 있음. **`/mnt/d` 경로는 작업에 쓰지 않음** — 이미 D에 있으니 굳이 9P-mounted Windows FS로 갈 이유가 없고, C 컴파일 시 권한 문제 발생.
- **원격 접속**: VS Code `code tunnel` — 핸드폰/태블릿/다른 데스크톱 어디에서든 노트북 셸·에디터에 붙어 작업.
- **저장소**: GitHub (`git@github.com:Sweet-Butters/Claude_in_Phone.git`, private). 기기 간 모든 sync는 여기를 거쳐서만.
- **인증**: 각 기기마다 ed25519 SSH 키를 따로 만들어 GitHub에 등록. 노트북 키는 `~/.ssh/id_ed25519`.

## 작업 원칙

1. **세션 시작 = `git pull --ff-only`** 부터. 다른 기기에서 만든 커밋을 먼저 받아오지 않으면 충돌·꼬임 확률이 올라감.
2. **세션 종료 = `git add` → `git commit` → `git push`까지 완료**하고 떠남. 미완성 코드라도 WIP 커밋으로 푸시해서 다음 기기에서 이어받을 수 있게.
3. **기기 간 직접 파일 복사 금지**. USB·클라우드 드라이브·메신저 전송 등으로 코드를 옮기지 않음. 모든 sync는 GitHub 경유.
4. **자동 진행 vs 명시적 확인**:
   - 일반 명령(파일 편집, 빌드, 통상 git 명령, 테스트 실행 등) → Claude가 사용자에게 따로 묻지 않고 즉시 진행.
   - Destructive·되돌리기 힘든 명령(`git push --force`, `git reset --hard`, `rm -rf` 등 작업 내역 손실 가능성이 있는 것) → 반드시 사용자 확인 후 실행.

## Claude Code 사용 시 참고

- 모바일에서 접속하는 경우가 많으니 응답은 짧고 가독성 우선. 긴 로그는 요약해서 전달.
- 경로 기준은 `/home/sweetbutters/...`. 절대 경로를 우선 사용 (Bash 도구는 호출 사이에 cwd가 유지되지 않음).
- 사용자 권한 모드는 `bypassPermissions`가 기본 (`~/.claude/settings.json`). Shift+Tab으로 다른 모드(default / acceptEdits / plan / bypassPermissions)로 토글 가능.

## 새 기기에서 처음 이 repo를 열 때

본 repo 외부의 환경 셋업이 먼저 필요:
1. WSL2 + Ubuntu 설치 (선택: `wsl --import`로 비-C 드라이브로 이전)
2. `git`, `gh`(GitHub CLI), `jq` 설치 — `sudo apt install -y git gh jq`
3. ed25519 SSH 키 생성 후 GitHub `settings/keys`에 등록
4. `gh auth login --hostname github.com --git-protocol ssh --web`
5. `git clone git@github.com:Sweet-Butters/Claude_in_Phone.git`

## Repo 구조

현재는 빈 skeleton. 작업이 추가되는 대로 이 섹션을 갱신.
