<div align="center">

# Claude in Phone

**Multi-device personal dev workflow: an always-on laptop WSL paired with a phone via Termius / VS Code Tunnel, with GitHub as the single sync path.**

[![License: MIT](https://img.shields.io/badge/License-MIT-yellow.svg)](LICENSE)
![Platform](https://img.shields.io/badge/platform-WSL2_Ubuntu_24.04-blue)
![Remote](https://img.shields.io/badge/remote-Termius_%2B_VS_Code_Tunnel-success)

[English](README.md) · [한국어](README.ko.md)

</div>

---

## Overview

A reproducible single-source-of-truth for a personal multi-device dev environment where:

- A laptop runs WSL2 Ubuntu around the clock as the always-on dev host.
- A phone, tablet, or any other PC connects remotely over two complementary paths — VS Code Tunnel for visual editing, Termius over Tailscale for terminal / Claude Code work.
- All sync between devices flows through GitHub — never via USB, cloud drives, or messengers.

This repo contains the setup guide, the systemd unit for the tunnel daemon, and a setup script so any new device can be onboarded in minutes.

## Architecture

```text
┌────────────────────────┐                  ┌──────────────────────┐
│  Laptop (always-on)    │                  │  Phone / Tablet / PC │
│  WSL2 Ubuntu 24.04     │ ◄── SSH ────────►│  Termius             │
│   • sshd               │   over tailnet   │  Tailscale           │
│   • VS Code Tunnel     │ ◄── HTTPS ──────►│  vscode.dev/tunnel/  │
│   • tmux               │                  │                      │
└──────────┬─────────────┘                  └──────────┬───────────┘
           │                                           │
           └──────────────── git push/pull ────────────┘
                       GitHub (single sync path)
```

## Environment

| Item | Value |
| --- | --- |
| OS | WSL2 Ubuntu 24.04 on Windows 10/11 |
| WSL virtual disk | Default location (system drive `.vhdx`) **or** moved via `wsl --import` — either way, work on **native ext4**, not on a 9P mount |
| Project path | `~/projects/Claude_in_Phone/` |
| **Forbidden work paths** | `/mnt/*` (9P-mounted Windows NTFS — slow, permission issues, breaks C compilation) |
| Remote | `git@github.com:<owner>/Claude_in_Phone.git` |
| Auth | per-device ed25519 SSH key (passphrase recommended), registered separately on GitHub |

> The "WSL moved to a non-system drive" case (e.g. `D:\WSL_Storage` via `wsl --import`) and the default-location case follow the same rule: **work on native ext4, not on `/mnt/*`.**

## Working Principles

1. **Session start = `git pull --ff-only`** — pull commits from other devices first.
2. **Session end = `git add` → `commit` → `push`** — even WIP. Anything not pushed is invisible to other devices.
3. **No direct file transfer between devices.** Sync goes through GitHub only.
4. **Auto-yes vs explicit confirmation** — routine commands (edit, build, plain `git`, tests) run without asking; destructive commands (`git push --force`, `git reset --hard`, `rm -rf`, …) require explicit user confirmation. This rule is global and belongs in `~/.claude/CLAUDE.md`, not duplicated per repo.

## Remote Access

Two parallel paths. Pick by task.

### A. VS Code Tunnel — visual editor

- **Use for**: code editing, file-tree review, markdown preview.
- **Daemon**: systemd user service ([`infra/vscode-tunnel.service`](infra/vscode-tunnel.service)). With `loginctl enable-linger <user>` set, it starts on WSL boot and restarts 5 s after a crash.
- **First-time GitHub auth**: on first start the service prints an 8-character device code to its journal. Read it with `journalctl --user -u vscode-tunnel.service` and enter it at https://github.com/login/device. The token is cached after that.
- **Connect from anywhere**: `https://vscode.dev/tunnel/<tunnel-name>/<workspace-path>`
- **Limitation**: VS Code's UI is awkward on a phone touch screen — use path B for mobile terminal work.

Operational commands:
```bash
systemctl --user status vscode-tunnel.service
journalctl --user -u vscode-tunnel.service -f
```

### B. SSH over Tailscale + Termius — mobile terminal

The path used most often from a phone. Drops you into a terminal where you launch `claude`.

**Networking** — Tailscale mesh VPN (encrypted P2P, works from any network):

| Device | Role |
| --- | --- |
| Laptop | sshd listener |
| Phone | Termius client |

> **Enable MagicDNS in the Tailscale admin console.** Then Termius can use hostnames (e.g. `laptop`) instead of IPs — a changing tailnet IP won't break the saved connection.

**Laptop setup**:
- `sudo apt install -y openssh-server` and `sudo systemctl enable --now ssh`
- Add the phone's Termius-generated ED25519 public key to `~/.ssh/authorized_keys`
- Harden `/etc/ssh/sshd_config`:
  ```
  PasswordAuthentication no
  PermitRootLogin no
  ```

**Phone setup** (Android / iOS):
- Tailscale app — sign in with the **same account** as the laptop.
- Termius — Host: tailnet hostname (with MagicDNS) or tailnet IPv4; Port: `22`; User: your linux user; Auth: SSH Key (generate in-app, copy the public key to the laptop).

**Recommended entry sequence** (`tmux` for connection-loss resilience):
```bash
tmux new -s work          # first time
tmux attach -t work       # subsequent connections
cd ~/projects/Claude_in_Phone
claude
```

## New Device Setup

Run [`scripts/setup-new-device.sh`](scripts/setup-new-device.sh) after cloning — it handles steps 2–4 + known_hosts in one go. Steps 6–7 (tunnel + tailnet) are intentionally manual.

**Base (code work only):**

1. WSL2 + Ubuntu 24.04 — from a Windows PowerShell: `wsl --install -d Ubuntu-24.04`
2. `sudo apt install -y git gh jq build-essential tmux`
3. Generate per-device ed25519 SSH key and register it at https://github.com/settings/keys
4. `gh auth login --hostname github.com --git-protocol ssh --web`
5. `git clone git@github.com:<owner>/Claude_in_Phone.git ~/projects/Claude_in_Phone`

**Optional — remote access:**

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
   # then paste the phone's Termius public key into ~/.ssh/authorized_keys
   ```

## Working with Claude Code

- Mobile use dominates — keep responses short; summarize long logs.
- Use absolute paths — the Bash tool's cwd does not persist across calls.
- Permission mode is `bypassPermissions` by default (`~/.claude/settings.json`); toggle with Shift+Tab.

## Security Hardening

`bypassPermissions` + mobile = highest risk of an unintended destructive command. Add hard-blocks in the global `~/.claude/settings.json` — `deny` patterns are enforced even in bypass mode:

```jsonc
{
  "permissions": {
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

Additional hygiene:

- Use a passphrase on each device's SSH key (`ssh-keygen -t ed25519` prompts for one).
- Treat each device's GitHub SSH key as separately revocable — on device loss, revoke that one key only.
- Keep GitHub recovery codes off-device (printed, or in a password manager on a separate device).

## Backup Strategy

Single failure points to be aware of:

- **GitHub** — every sync goes through it; account lockout = sync paralysis. Keep recovery codes printed; consider a backup PAT in an offline location.
- **WSL virtual disk (`.vhdx`)** — lives only on the local Windows host. Disk loss = every uncommitted line is gone. Mitigate by strictly following rule 2 (push at end of session). For extra safety, back up the `.vhdx` folder (e.g. `C:\Users\<user>\AppData\Local\Packages\CanonicalGroupLimited.*\LocalState\`) to OneDrive or an external drive periodically.
- **SSH keys** — generated per device; if a device is lost or compromised, revoke that key on GitHub. Never share one key across devices.

## Repository Layout

```
.
├── README.md                    # this document (English)
├── README.ko.md                 # 한국어 버전
├── CLAUDE.md                    # Claude Code context (slim, refers to README)
├── LICENSE                      # MIT
├── infra/
│   └── vscode-tunnel.service    # systemd user unit
└── scripts/
    └── setup-new-device.sh      # automates new-device base setup
```

## License

MIT. See [LICENSE](LICENSE).
