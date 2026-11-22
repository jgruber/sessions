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
```

The alias append is idempotent — running the installer twice doesn't
duplicate the line.

## Usage

```
sessions                     interactive menu on default host (localhost)
sessions <host>              interactive menu on <host> (via SSH)
sessions <host> ls           list sessions, non-interactive
sessions <host> new [name]   create a session (named or auto) and attach
sessions <host> attach name  attach to an existing session
sessions <host> kill name    kill a session
```

`<host>` of `localhost` (or the current machine's hostname) talks to tmux
directly with no SSH round-trip. Any other value is passed to `ssh` — so SSH
host aliases from `~/.ssh/config` work.

Set a different default host in your shell rc:

```sh
export SESSIONS_HOST=gateway0
```

## Interactive menu

```
#    NAME                 STARTED            LAST CONNECTED     STATE
---  ----                 -------            --------------     -----
1    work                 2h ago             just now           attached
2    email                3d ago             1h ago             detached
3    compile              30m ago            never              detached
0    [new session]

[number] attach   0 new   d <number> kill   q quit
```

- Type a **number** to attach to that session.
- Type **0** (or `n`) to create a new session — you'll be prompted for a host
  (defaults to the current scope, e.g. `localhost`) and a name (blank → auto).
  Shortcut form: `n build @gateway0`.
- Type **d <number>** to kill a session (with confirmation).
- Type **q** to quit.

If there are no sessions on the host, `sessions` proactively offers to create
one before dropping to the menu.

After you detach with `Ctrl-b d`, you land back in the menu — pick the number
again to reconnect.

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
