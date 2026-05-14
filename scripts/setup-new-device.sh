#!/usr/bin/env bash
# New-device setup for the Claude_in_Phone workflow.
# Handles steps 2-4 from README.md plus known_hosts setup.
# Steps 1 (WSL install), 5 (clone — assumed already done since you're running this),
# 6 (VS Code Tunnel daemon), and 7 (SSH over Tailscale) remain manual — see README.

set -euo pipefail

echo "== [1/4] Sanity check: WSL2"
if ! grep -qi microsoft /proc/version 2>/dev/null; then
  echo "  Warning: this does not look like WSL. Press Ctrl+C to abort, or Enter to continue."
  read -r _
fi
echo "  OK."

echo
echo "== [2/4] Base packages"
sudo apt update
sudo apt install -y git gh jq build-essential tmux

echo
echo "== [3/4] ed25519 SSH key"
if [[ -f "$HOME/.ssh/id_ed25519" ]]; then
  echo "  ~/.ssh/id_ed25519 already exists — skipping generation."
else
  read -rp "  GitHub email for the key comment: " github_email
  ssh-keygen -t ed25519 -C "$github_email" -f "$HOME/.ssh/id_ed25519"
fi
echo
echo "  Public key (paste at https://github.com/settings/keys):"
echo "  --------------------------------------------------------------"
cat "$HOME/.ssh/id_ed25519.pub"
echo "  --------------------------------------------------------------"
read -rp "  Press Enter once the key is registered on GitHub..." _

echo
echo "== [4/4] gh auth + known_hosts"
if gh auth status &>/dev/null; then
  echo "  gh already authenticated — skipping."
else
  gh auth login --hostname github.com --git-protocol ssh --web
fi

mkdir -p "$HOME/.ssh"
chmod 700 "$HOME/.ssh"
if ! ssh-keygen -F github.com -f "$HOME/.ssh/known_hosts" &>/dev/null; then
  ssh-keyscan -t ed25519 github.com >> "$HOME/.ssh/known_hosts" 2>/dev/null
  echo "  github.com host key added to known_hosts."
else
  echo "  github.com already in known_hosts."
fi

echo
echo "Setup complete. Next steps:"
echo "  - Test SSH:           ssh -T git@github.com"
echo "  - Optional step 6:    VS Code Tunnel daemon  (see README)"
echo "  - Optional step 7:    SSH over Tailscale     (see README)"
