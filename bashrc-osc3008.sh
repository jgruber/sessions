# bashrc-osc3008.sh — snippet to silence systemd's OSC 3008 shell-integration.
# Append to ~/.bashrc (or source from it). Idempotent: safe to source twice.
#
# Background:
#   systemd >= 256 ships /etc/profile.d/80-systemd-osc-context.sh which hooks
#   PROMPT_COMMAND and PS0 to emit OSC 3008 "Hierarchical Context Signalling"
#   sequences (UAPI.15, https://uapi-group.org/specifications/specs/osc_context/)
#   at every prompt. Terminal emulators that don't yet understand OSC 3008
#   render the payload as visible garbage like:
#       3008;start=UUID;type=shell;machineid=...;cwd=/path
#   and stray fragments can leak back into bash as "command not found".
#   Most noticeable when a fresh tmux pane spawns a new login shell — i.e.
#   the exact workflow `sessions` creates.
#
#   This snippet leaves the PROMPT_COMMAND/PS0 chain intact (pyenv etc. rely
#   on it) and just redefines the systemd hooks as no-ops.
#
# To re-enable: comment the block out and open a new shell.

if declare -F __systemd_osc_context_precmdline >/dev/null 2>&1; then
  __systemd_osc_context_precmdline() { :; }
  __systemd_osc_context_ps0()        { :; }
fi
