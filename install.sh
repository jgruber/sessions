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
#   ALIAS         if set, add 'alias <ALIAS>=sessions' to the target user's
#                 shell rc (bash/zsh/fish auto-detected). Example: ALIAS=s
#   TMUX_CONF     1 = install ~/.tmux.conf from this repo's tmux.conf.
#                 Won't overwrite an existing file unless FORCE_TMUX_CONF=1.
#   FIX_OSC3008   1 = append the systemd OSC 3008 no-op snippet to the
#                 target user's bash rc (bashrc-osc3008.sh). Idempotent.

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

# --- optional alias install ----------------------------------------------
install_alias() {
  local name="${ALIAS:-}"
  [[ -z "$name" ]] && return 0

  if ! [[ "$name" =~ ^[a-zA-Z_][a-zA-Z0-9_]*$ ]]; then
    die "invalid ALIAS name: '$name' (must match [a-zA-Z_][a-zA-Z0-9_]*)"
  fi

  # Pick shell: for cross-user installs, consult passwd; otherwise $SHELL.
  local target_shell
  if [[ -n "${TARGET_USER:-}" ]] && [[ "$TARGET_USER" != "${USER:-$(id -un)}" ]]; then
    target_shell="$(getent passwd "$TARGET_USER" | cut -d: -f7)"
  else
    target_shell="${SHELL:-/bin/bash}"
  fi
  target_shell="$(basename "$target_shell")"

  local rc
  case "$target_shell" in
    bash) rc="$TARGET_HOME/.bashrc" ;;
    zsh)  rc="$TARGET_HOME/.zshrc"  ;;
    fish) rc="$TARGET_HOME/.config/fish/config.fish" ;;
    *)
      say "unknown shell '$target_shell' — skipping alias install"
      say "add this to your rc manually:  alias $name=sessions"
      return 0
      ;;
  esac

  mkdir -p "$(dirname "$rc")"
  touch "$rc"

  # Idempotent: match "alias NAME=sessions" with optional trailing comment.
  if grep -Eq "^[[:space:]]*alias[[:space:]]+${name}=sessions([[:space:]]|$)" "$rc"; then
    say "alias '$name' already present in $rc"
  else
    {
      printf '\n# added by sessions installer\n'
      printf 'alias %s=sessions\n' "$name"
    } >> "$rc"
    say "Added 'alias $name=sessions' to $rc"
    say "Start a new shell, or run:  source $rc"
  fi

  if [[ -n "${TARGET_USER:-}" ]] && [[ "$TARGET_USER" != "${USER:-$(id -un)}" ]]; then
    chown "$TARGET_USER" "$rc" 2>/dev/null || true
  fi
}

# --- optional terminal-setup bundles --------------------------------------
# Two gotchas that only matter once you're using sessions:
#   1. Fresh bash login shells (which tmux spawns) can print systemd's OSC
#      3008 shell-integration bytes as visible garbage in terminals that
#      don't speak OSC 3008 yet.
#   2. tmux's default is to use the terminal's alternate screen and a 2000-
#      line history, so terminal scroll-up doesn't work inside a session.
# Both opt in via env var so default install touches no config files.

install_osc3008_fix() {
  [[ "${FIX_OSC3008:-0}" == "1" ]] || return 0
  local rc="$TARGET_HOME/.bashrc"
  touch "$rc"
  if grep -q '__systemd_osc_context_precmdline() { :;' "$rc"; then
    say "OSC 3008 no-op already present in $rc"
    return 0
  fi
  {
    printf '\n# added by sessions installer: silence systemd OSC 3008 shell-integration\n'
    printf '# (see /etc/profile.d/80-systemd-osc-context.sh)\n'
    printf 'if declare -F __systemd_osc_context_precmdline >/dev/null 2>&1; then\n'
    printf '  __systemd_osc_context_precmdline() { :; }\n'
    printf '  __systemd_osc_context_ps0()        { :; }\n'
    printf 'fi\n'
  } >> "$rc"
  say "Added OSC 3008 no-op to $rc"
  if [[ -n "${TARGET_USER:-}" ]] && [[ "$TARGET_USER" != "${USER:-$(id -un)}" ]]; then
    chown "$TARGET_USER" "$rc" 2>/dev/null || true
  fi
}

install_tmux_conf() {
  [[ "${TMUX_CONF:-0}" == "1" ]] || return 0
  local dest="$TARGET_HOME/.tmux.conf"
  if [[ -e "$dest" ]] && [[ "${FORCE_TMUX_CONF:-0}" != "1" ]]; then
    say "$dest exists; not overwriting. Pass FORCE_TMUX_CONF=1 to replace it."
    return 0
  fi
  local tmp
  tmp="$(mktemp)"
  say "Downloading tmux.conf -> $dest"
  curl -fsSL "$RAW_BASE/tmux.conf" -o "$tmp"
  mv "$tmp" "$dest"
  if [[ -n "${TARGET_USER:-}" ]] && [[ "$TARGET_USER" != "${USER:-$(id -un)}" ]]; then
    chown "$TARGET_USER" "$dest" 2>/dev/null || true
  fi
  # Reload a running server, if the target user has one.
  if command -v tmux >/dev/null 2>&1; then
    local reload_cmd=(tmux source-file "$dest")
    if [[ -n "${TARGET_USER:-}" ]] && [[ "$TARGET_USER" != "${USER:-$(id -un)}" ]]; then
      reload_cmd=(sudo -u "$TARGET_USER" tmux source-file "$dest")
    fi
    "${reload_cmd[@]}" 2>/dev/null && say "Reloaded running tmux server"
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
install_alias
install_tmux_conf
install_osc3008_fix
say "Installed. Run:  sessions"
path_hint
