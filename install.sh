#!/usr/bin/env bash
# Installer for the 'sessions' tmux wrapper.
#
# One-liner:
#   curl -fsSL https://raw.githubusercontent.com/jgruber/sessions/main/install.sh | bash
#
# Supported distros: Debian/Ubuntu, Arch/Manjaro/EndeavourOS, Fedora/RHEL/CentOS/Rocky/Alma.
#
# Environment overrides:
#   INSTALL_DIR   target bin directory         (default: $HOME/.local/bin)
#   BRANCH        repo branch to pull from     (default: main)
#   RAW_BASE      raw file base URL            (default: GitHub raw for jgruber/sessions)
#   SKIP_TMUX     set to 1 to skip tmux install
#   TARGET_USER   install for this user instead of $USER (requires root or sudo)

set -euo pipefail

BRANCH="${BRANCH:-main}"
RAW_BASE="${RAW_BASE:-https://raw.githubusercontent.com/jgruber/sessions/$BRANCH}"

# --- resolve target user & home -------------------------------------------
if [[ -n "${TARGET_USER:-}" ]]; then
  if [[ $EUID -ne 0 ]]; then
    echo "TARGET_USER requires root (re-run with sudo)." >&2
    exit 2
  fi
  TARGET_HOME="$(getent passwd "$TARGET_USER" | cut -d: -f6)"
  [[ -n "$TARGET_HOME" ]] || { echo "unknown user: $TARGET_USER" >&2; exit 2; }
else
  TARGET_USER="${USER:-$(id -un)}"
  TARGET_HOME="$HOME"
fi

INSTALL_DIR="${INSTALL_DIR:-$TARGET_HOME/.local/bin}"

say() { printf "[sessions-install] %s\n" "$*"; }
die() { printf "[sessions-install] ERROR: %s\n" "$*" >&2; exit 1; }

# Root? sudo? plain?
if [[ $EUID -eq 0 ]]; then
  SUDO=""
elif command -v sudo >/dev/null 2>&1; then
  SUDO="sudo"
else
  SUDO=""
fi

# --- tmux install ---------------------------------------------------------
install_tmux() {
  if command -v tmux >/dev/null 2>&1; then
    say "tmux already installed: $(tmux -V)"
    return 0
  fi
  if [[ "${SKIP_TMUX:-0}" == "1" ]]; then
    say "SKIP_TMUX=1, skipping tmux install."
    return 0
  fi
  [[ -f /etc/os-release ]] || die "cannot detect OS: /etc/os-release missing"
  # shellcheck disable=SC1091
  . /etc/os-release
  local id_all="${ID:-} ${ID_LIKE:-}"

  case " $id_all " in
    *" debian "*|*" ubuntu "*|*" linuxmint "*|*" pop "*)
      say "Installing tmux via apt..."
      $SUDO apt-get update -qq
      $SUDO apt-get install -y tmux
      ;;
    *" arch "*|*" archlinux "*|*" manjaro "*|*" endeavouros "*)
      say "Installing tmux via pacman (full system sync, per Arch recommendation)..."
      # Arch does not support partial upgrades: 'pacman -Sy pkg' can break
      # the system when pkg depends on libs newer than those currently
      # installed. '-Syu' refreshes the database and upgrades everything,
      # which is the only safe way to install a new package non-interactively.
      $SUDO pacman -Syu --noconfirm tmux
      ;;
    *" fedora "*|*" rhel "*|*" centos "*|*" rocky "*|*" almalinux "*|*" ol "*)
      if command -v dnf >/dev/null 2>&1; then
        say "Installing tmux via dnf..."
        $SUDO dnf install -y tmux
      else
        say "Installing tmux via yum..."
        $SUDO yum install -y tmux
      fi
      ;;
    *)
      die "unsupported distro (ID=${ID:-?} ID_LIKE=${ID_LIKE:-}). Install tmux manually, then re-run with SKIP_TMUX=1."
      ;;
  esac
}

# --- fetch & install script ----------------------------------------------
install_script() {
  mkdir -p "$INSTALL_DIR"
  local dest="$INSTALL_DIR/sessions"
  local tmp
  tmp="$(mktemp)"
  say "Downloading sessions -> $dest"
  curl -fsSL "$RAW_BASE/sessions" -o "$tmp"
  chmod +x "$tmp"
  mv "$tmp" "$dest"

  # If installing for another user, fix ownership.
  if [[ -n "${TARGET_USER:-}" ]] && [[ "$TARGET_USER" != "${USER:-$(id -un)}" ]]; then
    chown "$TARGET_USER" "$dest" 2>/dev/null || true
    chown "$TARGET_USER" "$INSTALL_DIR" 2>/dev/null || true
  fi
}

# --- PATH check -----------------------------------------------------------
path_hint() {
  # Only meaningful when installing for the current user
  if [[ -n "${TARGET_USER:-}" ]] && [[ "$TARGET_USER" != "${USER:-$(id -un)}" ]]; then
    return 0
  fi
  case ":$PATH:" in
    *":$INSTALL_DIR:"*) ;;
    *)
      cat <<EOF

NOTE: $INSTALL_DIR is not currently in your PATH.
Add this to your ~/.bashrc, ~/.zshrc, or equivalent:

    export PATH="\$HOME/.local/bin:\$PATH"

Then restart your shell or source the rc file.

EOF
      ;;
  esac
}

install_tmux
install_script
say "Installed. Run:  sessions"
path_hint
