# sessions

A friendly tmux session manager. Lets you type `sessions` and get an
interactive menu to see, attach, create, and kill tmux sessions — locally or
on any host you can SSH to — without memorizing tmux syntax.

The only tmux keystroke you need to remember is **Ctrl-b d** (detach).

## Install

One-liner:

```sh
curl -fsSL https://raw.githubusercontent.com/jgruber/sessions/main/install.sh | bash
```

Installs `sessions` to `~/.local/bin/sessions` for the current user and
installs `tmux` from the system package manager if it's missing.

Supported package managers / distros:
- Debian, Ubuntu, Linux Mint, Pop!\_OS (`apt`)
- Arch, Manjaro, EndeavourOS (`pacman`)
- Fedora, RHEL, CentOS, Rocky, Alma, Oracle (`dnf` / `yum`)

### Install options

```sh
# Skip tmux install (install tmux yourself or already have it)
curl -fsSL .../install.sh | SKIP_TMUX=1 bash

# Install into a different directory
curl -fsSL .../install.sh | INSTALL_DIR=/usr/local/bin sudo bash

# Install for a different user (requires root)
curl -fsSL .../install.sh | sudo TARGET_USER=alice bash

# Also add a short alias to your shell rc (bash/zsh/fish detected automatically)
curl -fsSL .../install.sh | ALIAS=s bash

# Install the bundled ~/.tmux.conf (mouse scrollback, 50k history limit)
curl -fsSL .../install.sh | TMUX_CONF=1 bash
# Overwrite an existing ~/.tmux.conf too:  TMUX_CONF=1 FORCE_TMUX_CONF=1 bash

# Silence systemd's OSC 3008 shell-integration bytes in ~/.bashrc
# (fixes the "garbage characters at the top of a fresh tmux pane")
curl -fsSL .../install.sh | FIX_OSC3008=1 bash
```

The alias append is idempotent — running the installer twice doesn't
duplicate the line.

## Usage

```
sessions                          interactive menu on default host (localhost)
sessions <host>                   interactive menu on <host> (via SSH)
sessions <host> ls                list sessions, non-interactive
sessions <host> new [name] [dir]  create a session (named or auto) with an
                                  optional starting directory, and attach
sessions <host> attach name       attach to an existing session
sessions <host> kill name         kill a session
```

`<host>` of `localhost` (or the current machine's hostname) talks to tmux
directly with no SSH round-trip. Any other value is passed to `ssh` — so SSH
host aliases from `~/.ssh/config` work.

Set a different default host in your shell rc:

```sh
export SESSIONS_HOST=gateway0
```

## Interactive menu

**When sessions exist:**

```
#    NAME                 STARTED            LAST CONNECTED     STATE
---  ----                 -------            --------------     -----
1    work                 2h ago             just now           attached
2    email                3d ago             1h ago             detached
3    compile              30m ago            never              detached

Connect to # (1-3) or [n]ew session?  (d <#> delete, q quit)
```

- Type a **number** to connect to that session.
- Type **n** (or just Enter) to create a new session. You'll be prompted for:
  - **host** (defaults to the current scope, e.g. `localhost`)
  - **name** (blank → auto-named with a timestamp)
  - **working directory** (blank → shell's home dir). Readline is on at this
    prompt — arrow keys to edit, Tab to complete filenames, and a leading
    `~` is expanded to `$HOME`. Tab completes against the *local*
    filesystem, which is right for localhost sessions; for remote hosts
    whose paths don't mirror the local box, type an absolute path.
- Type **d <number>** to kill a session (with confirmation).
- Type **q** to quit.

Shortcut form at the prompt: `n build @gateway0` — create "build" on gateway0.

**When no sessions exist**, only the create option is offered:

```
No sessions on localhost.
Create a new session? [Y/n]
```

After you detach with `Ctrl-b d`, you land back in the menu — pick the number
again to reconnect.

## Terminal setup bundles

Two gotchas you only notice once you're using `sessions`, bundled here so
they live next to the tool that exposes them. Both opt in via `install.sh`
env var or you can drop the files in by hand.

### `tmux.conf` — mouse scrollback and a 50k history

Vanilla tmux captures the terminal's alternate screen, so scroll-up in your
SSH client does nothing inside a session. The shipped `~/.tmux.conf` turns
mouse mode on (wheel enters copy-mode and scrolls tmux's own history),
bumps the history limit from tmux's default 2000 lines to 50000, and binds
**Alt+PageUp** to jump straight into copy-mode scrolled up. Shift+drag still
selects text at the terminal level if you want to copy across the tmux
boundary.

```sh
curl -fsSL .../install.sh | TMUX_CONF=1 bash
#   FORCE_TMUX_CONF=1    overwrite an existing ~/.tmux.conf
```

Or drop [`tmux.conf`](tmux.conf) at `~/.tmux.conf` yourself. Reload a live
server with `tmux source-file ~/.tmux.conf`.

### `bashrc-osc3008.sh` — silence the "garbage in new tmux panes"

On systemd ≥ 256 (Ubuntu 26.04, Debian trixie, Fedora 40+)
`/etc/profile.d/80-systemd-osc-context.sh` hooks every bash prompt to emit
**OSC 3008 "Hierarchical Context Signalling"** (UAPI.15,
<https://uapi-group.org/specifications/specs/osc_context/>) bytes like:

```
\e]3008;start=<uuid>;type=shell;machineid=...;cwd=/path\e\
```

Terminals that already speak OSC 3008 swallow it; most don't yet, so the
payload prints as visible junk at the top of every fresh tmux pane (and
stray fragments can even land back in bash as "command not found").

The snippet redefines the two systemd shell-integration functions as no-ops
without touching `PROMPT_COMMAND` or `PS0` (so pyenv/nvm hooks keep working):

```sh
curl -fsSL .../install.sh | FIX_OSC3008=1 bash
```

Or append [`bashrc-osc3008.sh`](bashrc-osc3008.sh) to your `~/.bashrc` by
hand. For a system-wide fix (requires root), the systemd script itself
tells you how at the top of the file.

## Why not screen / byobu / zellij?

- **screen** — tolerable but its syntax is painful enough that a wrapper is
  the point of this repo.
- **byobu** — great if you want a status bar and F-key menus baked in.
  `sessions` is lighter: one shell script, no tmux config overrides.
- **zellij / sesh / tmux-sessionizer** — all good, if you're willing to adopt
  more tooling. `sessions` aims for "no new keystrokes to learn."

## Requirements

- bash 4+ (ships on all supported distros)
- tmux (installed by the installer, or bring your own)
- openssh-client (for remote hosts)
