#!/usr/bin/env sh

#= file: ~/.config/fish/conf.d/termtty_idle_watcher_core.fish

#= A portable idle watcher that runs a command if the terminal
#= has been idle (no user keystrokes hitting prompt) for N seconds.
#= Supports enable flag, child cleanup, and interactive abort via ESC or CTRL-C.

#= = script usage:
#= =   termtty_idle_watcher_core.sh --timeout 300 --cmd "/path/to/script arg1 arg2" [--once]
#= = environment overrides:
#= =   TERMTTY_IDLE_TIMEOUT, TERMTTY_IDLE_ACTIVITY_FILE, TERMTTY_IDLE_CMD, TERMTTY_IDLE_ONCE

termtty_idle_watcher_log() {
    #= basic logger to stderr with timestamp
    # shellcheck disable=SC2039
    printf '%s [%s] %s\n' "$(date +'%Y-%m-%dT%H:%M:%S%z')" "termtty_idle_watcher" "$*" >&2
}


#= ----[ early disable gate; set TERMTTY_IDLE_WATCHER_ENABLE=0 to fully disable ]-----------------
if [ "${TERMTTY_IDLE_WATCHER_ENABLE:-0}" = "0" ]; then
  termtty_idle_watcher_log "disabled via TERMTTY_IDLE_WATCHER_ENABLE=0; exiting."
  exit 0
fi


termtty_idle_watcher_usage() {
  cat <<EOF
Usage: $0 --timeout <seconds> --cmd "<command to run>" [--once]

Options:
  --enabled <0|1>          Enable(1) or Disable(0) Watcher (or env TERMTTY_IDLE_WATCHER_ENABLE)
  --activity-file <file>   Activity timestamp file (or env TERMTTY_IDLE_WATCHER_ACTFILE)
  --cmd "<command>"        Command to exec when idle (or env TERMTTY_IDLE_WATCHER_CMD)
  --once                   Only fire once then exit (or env TERMTTY_IDLE_WATCHER_ONCE=1)
  --timeout <sec>          Idle threshold in seconds (or env TERMTTY_IDLE_WATCHER_TIMEOUT)
  --help                   Show this help

Env defaults:
  TERMTTY_IDLE_WATCHER_ENABLE
  TERMTTY_IDLE_WATCHER_ACTFILE
  TERMTTY_IDLE_WATCHER_CMD
  TERMTTY_IDLE_WATCHER_ONCE
  TERMTTY_IDLE_WATCHER_TIMEOUT
EOF
}


#= ----[ parse args ]-----------------------------------------------------------------------------
TERMTTY_IDLE_WATCHER_ONCE_FLAG=0


while [ $# -gt 0 ]; do
    case "$1" in
        --timeout)
            shift
            TERMTTY_IDLE_WATCHER_TIMEOUT="$1"
            ;;
        --cmd)
            shift
            TERMTTY_IDLE_WATCHER_CMD="$1"
            ;;
        --activity-file)
            shift
            TERMTTY_IDLE_WATCHER_ACTFILE="$1"
            ;;
        --once)
            TERMTTY_IDLE_WATCHER_ONCE_FLAG=1
            ;;
        --help|-h)
            termtty_idle_watcher_usage
            exit 0
            ;;
        *)
            termtty_idle_watcher_log "ERRR: Unknown arg '$1'"
            termtty_idle_watcher_usage
            exit 1
            ;;
    esac
    shift
done


#= ----[ apply env fallbacks ]--------------------------------------------------------------------
[ -n "${TERMTTY_IDLE_WATCHER_ONCE}" ] && TERMTTY_IDLE_WATCHER_ONCE_FLAG=${TERMTTY_IDLE_WATCHER_ONCE}
[ -z "${TERMTTY_IDLE_WATCHER_TIMEOUT}" ] && TERMTTY_IDLE_WATCHER_TIMEOUT="${TERMTTY_IDLE_WATCHER_TIMEOUT:-300}"
[ -z "${TERMTTY_IDLE_WATCHER_CMD}" ] && TERMTTY_IDLE_WATCHER_CMD="${TERMTTY_IDLE_WATCHER_CMD:-echo IDLE THRESHOLD reached}"
UID_FALLBACK="$(id -u 2>/dev/null || echo $$)"
[ -z "${TERMTTY_IDLE_WATCHER_ACTFILE}" ] && TERMTTY_IDLE_WATCHER_ACTFILE="${HOME:-~}/.termtty_idle_watcher_act.${UID_FALLBACK}"

#= ----[ sanity checks ]--------------------------------------------------------------------------
case "${TERMTTY_IDLE_WATCHER_TIMEOUT}" in
    ''|*[!0-9]*)
        termtty_idle_watcher_log "ERRR: --timeout must be integer seconds"
        exit 1
        ;;
esac

if [ -z "${TERMTTY_IDLE_WATCHER_CMD}" ]; then
    termtty_idle_watcher_log "ERRR: --cmd required or TERMTTY_IDLE_WATCHER_CMD must be set"
    exit 1
fi


#= ----[ ensure activity file exists with "now" ]-------------------------------------------------
if [ ! -f "${TERMTTY_IDLE_WATCHER_ACTFILE}" ]; then
    date +%s > "${TERMTTY_IDLE_WATCHER_ACTFILE}" 2>/dev/null || {
        termtty_idle_watcher_log "ERRR: cannot write activity file ${TERMTTY_IDLE_WATCHER_ACTFILE}"
        exit 1
    }
fi


#= ----[ child tracking, list of spawned child pids (space separated) ]---------------------------
TERMTTY_IDLE_WATCHER_PIDS_CHILD=""


#= add a child PID to our list
termtty_idle_watcher_add_child() {
  pid_child="$1"
  if [ -n "${pid_child}" ]; then
    if [ -z "${TERMTTY_IDLE_WATCHER_PIDS_CHILD}" ]; then
      TERMTTY_IDLE_WATCHER_PIDS_CHILD="${pid_child}"
    else
      TERMTTY_IDLE_WATCHER_PIDS_CHILD="${TERMTTY_IDLE_WATCHER_PIDS_CHILD} ${pid_child}"
    fi
  fi
}


#= ----[ kill all children we spawned ]-----------------------------------------------------------
termtty_idle_watcher_kill_children() {
  for pid_child in ${TERMTTY_IDLE_WATCHER_PIDS_CHILD}; do
    #= check if still alive
    if kill -0 "${pid_child}" 2>/dev/null; then
      termtty_idle_watcher_log "killing child pid ${pid_child}"
      kill "${pid_child}" 2>/dev/null || true
    fi
  done
}


#= ----[ signal & key handler setup ]-------------------------------------------------------------
termtty_idle_watcher_alive=1

termtty_idle_watcher_add_child() { TERMTTY_IDLE_WATCHER_PIDS_CHILD="${TERMTTY_IDLE_WATCHER_PIDS_CHILD} $1"; }

termtty_idle_watcher_kill_children() {
  for pid_child in ${TERMTTY_IDLE_WATCHER_PIDS_CHILD}; do
    kill "${pid_child}" 2>/dev/null || true
  done
}
#= ----[ signal handler ]-------------------------------------------------------------------------
termtty_idle_watcher_handle_signal() {
  termtty_idle_watcher_log "received termination sig; user interrupt or keypress — terminating..."
  termtty_idle_watcher_kill_children
  termtty_idle_watcher_alive=0
}
#= handle:trap signals so we can kill children - also handle Ctrl-\\ (SIGQUIT)
trap 'termtty_idle_watcher_handle_signal' INT TERM QUIT



FIRED_ONCE=0

#= ----[ termtty_idle_watcher: banner ]---------------------------
termtty_idle_watcher_log "starting termtty_idle_watcher: timeout=${TERMTTY_IDLE_WATCHER_TIMEOUT}s once=${TERMTTY_IDLE_WATCHER_ONCE_FLAG} file=${TERMTTY_IDLE_WATCHER_ACTFILE}"
termtty_idle_watcher_log "will run: ${TERMTTY_IDLE_WATCHER_CMD}"

while [ "${termtty_idle_watcher_alive}" -eq 1 ]; do
    #= current epoch seconds
    time_now="$(date +%s)"
    time_last="$(cat "${TERMTTY_IDLE_WATCHER_ACTFILE}" 2>/dev/null || echo "${time_now}")"
    #= compute delta
    # shellcheck disable=SC2039
    time_delta=$(( time_now - time_last ))

    if [ "${time_delta}" -ge "${TERMTTY_IDLE_WATCHER_TIMEOUT}" ]; then
        if [ "${TERMTTY_IDLE_WATCHER_ONCE_FLAG}" -eq 1 ] && [ "${FIRED_ONCE}" -eq 1 ]; then
            #= already fired once, we can just idle sleep
            :
        else
          termtty_watcher_log "idle threshold reached (time_delta=${time_delta}s >= ${TERMTTY_IDLE_WATCHER_TIMEOUT}s); executing command."
          
          #= 1) spawn the user command, prefer the controlling TTY, but don't die if it's missing
          if [ -t 1 ] && [ -e /dev/tty ]; then
            #= run on the real terminal so output is visible
            sh -c "${TERMTTY_IDLE_WATCHER_CMD}" </dev/tty >/dev/tty 2>&1 &
          else
            #= fallback: inherit whatever stdout/stderr we have
            sh -c "${TERMTTY_IDLE_WATCHER_CMD}" &
          fi
          CMD_PID=$!
          
          #= 2) track the child so signals / ESC can kill it later
          termtty_idle_watcher_add_child "${CMD_PID}"
          termtty_idle_watcher_log "spawned idle cmd, pid=${CMD_PID}"
          
          #= 3) mark that we have fired
          FIRED_ONCE=1
          
          #= 4) if we're a one-shot watcher, don't kill the child right now,
          #=    just break after the loop cleanup
          if [ "${TERMTTY_IDLE_WATCHER_ONCE_FLAG}" -eq 1 ]; then
            termtty_idle_watcher_log "once flag set; exiting after current idle command finishes (child pid=${CMD_PID})."
            #= NOTE: do NOT call termtty_idle_watcher_kill_children here
            #= we want to let the idle cmd run!
            termtty_idle_watcher_alive=0
          else
            #= 5) reset activity so we don't immediately re-fire
            date +%s >"${TERMTTY_IDLE_WATCHER_ACTFILE}" 2>/dev/null
          fi
        fi
    fi

    #= ----[ interactive abort (ESC) ]-------------------------------------------------------------------------
    #= read 1 char with short timeout; if ESC, quit; this only works if we still have a controlling TTY
    if [ -t 0 ] && [ -e /dev/tty ]; then
      #= NOTE: -t 0.1 is POSIX-ish but some shells need integer; fallback to 0
      #= try fractional first
      if read -r -t 0.1 -n 1 key 2>/dev/null; then
        case "${key}" in
          "$(printf '\033')")
            termtty_idle_watcher_log "ESC key pressed; exiting watcher."
            termtty_idle_watcher_handle_signal
            break
          ;;
        esac
      else
        # some shells (dash) don't like -n, so ignore errors silently
        :
      fi
    fi

    #= poll interval (seconds)
    sleep 1
done


#= ----[ final cleanup before exit ]--------------------------------------------------------------
termtty_idle_watcher_kill_children
termtty_idle_watcher_log "watcher exiting."
exit 0
