# Shell aliases for running Claude Code inside a persistent tmux session
# named "claude". The session survives terminal close, so a desktop
# session started before leaving home can be reattached from a phone
# over SSH (Termius) without losing context.
#
# Install (one-time, on each device):
#   cat scripts/claude-tmux-aliases.sh >> ~/.bashrc && source ~/.bashrc
#
# Usage:
#   claude     start (or attach to) the persistent "claude" tmux session
#   cc         quick reattach from a fresh shell (e.g. mobile SSH) without
#              spawning a second claude process
#
# Detach without killing the session: Ctrl+b then d
# List sessions:                      tmux ls

# Run Claude Code inside a tmux session named "claude". The -A flag
# attaches to an existing session if one exists, otherwise creates one,
# so the same command works for first launch and for re-entry.
alias claude='tmux new -A -s claude claude'

# Bare reattach — typically used after SSH'ing in from a phone, when
# the claude process is already running on the desktop.
alias cc='tmux attach -t claude'
