#!/usr/bin/env sh

#= termtty_idle_watcher_core.sh
#= A portable idle watcher that runs a command if the terminal
#= has been idle (no user keystrokes hitting prompt) for N seconds.

#= default comment indicator= '#'
#= = script usage:
#= =   termtty_idle_watcher_core.sh --timeout 300 --cmd "/path/to/script arg1 arg2" [--once]
#= = environment overrides:
#= =   TERMTTY_IDLE_TIMEOUT, TERMTTY_IDLE_ACTIVITY_FILE, TERMTTY_IDLE_CMD, TERMTTY_IDLE_ONCE

termtty_idle_log() {
    #= basic logger to stderr with timestamp
    # shellcheck disable=SC2039
    printf '%s [%s] %s\n' "$(date +'%Y-%m-%dT%H:%M:%S%z')" "termtty_idle_watcher" "$*" >&2
}

termtty_idle_usage() {
    cat <<EOF
Usage: $0 --timeout <seconds> --cmd "<command to run>" [--once]

Options:
  --activity-file <file>   Activity timestamp file (or env TERMTTY_IDLE_ACTIVITY_FILE)
  --cmd "<command>"        Command to exec when idle (or env TERMTTY_IDLE_CMD)
  --once                   Only fire once then exit (or env TERMTTY_IDLE_ONCE=1)
  --timeout <sec>          Idle threshold in seconds (or env TERMTTY_IDLE_TIMEOUT)
  --help                   Show this help

Env defaults:
  TERMTTY_IDLE_ACTIVITY_FILE
  TERMTTY_IDLE_CMD
  TERMTTY_IDLE_ONCE
  TERMTTY_IDLE_TIMEOUT
EOF
}

TERMTTY_IDLE_ONCE_FLAG=0

#= parse args
while [ $# -gt 0 ]; do
    case "$1" in
        --timeout)
            shift
            TERMTTY_IDLE_TIMEOUT="$1"
            ;;
        --cmd)
            shift
            TERMTTY_IDLE_CMD="$1"
            ;;
        --activity-file)
            shift
            TERMTTY_IDLE_ACTIVITY_FILE="$1"
            ;;
        --once)
            TERMTTY_IDLE_ONCE_FLAG=1
            ;;
        --help|-h)
            termtty_idle_usage
            exit 0
            ;;
        *)
            termtty_idle_log "ERRR: Unknown arg '$1'"
            termtty_idle_usage
            exit 1
            ;;
    esac
    shift
done

#= apply env fallbacks
[ -n "$TERMTTY_IDLE_ONCE" ] && TERMTTY_IDLE_ONCE_FLAG=$TERMTTY_IDLE_ONCE
[ -z "$TERMTTY_IDLE_TIMEOUT" ] && TERMTTY_IDLE_TIMEOUT="${TERMTTY_IDLE_TIMEOUT:-300}"
[ -z "$TERMTTY_IDLE_CMD" ] && TERMTTY_IDLE_CMD="${TERMTTY_IDLE_CMD:-echo IDLE THRESHOLD reached}"
UID_FALLBACK="$(id -u 2>/dev/null || echo $$)"
[ -z "$TERMTTY_IDLE_ACTIVITY_FILE" ] && TERMTTY_IDLE_ACTIVITY_FILE="${HOME:-~}/.termtty_idle_watcher_activity.$UID_FALLBACK"

#= sanity checks
case "$TERMTTY_IDLE_TIMEOUT" in
    ''|*[!0-9]*)
        termtty_idle_log "ERRR: --timeout must be integer seconds"
        exit 1
        ;;
esac

if [ -z "$TERMTTY_IDLE_CMD" ]; then
    termtty_idle_log "ERRR: --cmd required or TERMTTY_IDLE_CMD must be set"
    exit 1
fi

#= ensure activity file exists with "now"
if [ ! -f "$TERMTTY_IDLE_ACTIVITY_FILE" ]; then
    date +%s > "$TERMTTY_IDLE_ACTIVITY_FILE" 2>/dev/null || {
        termtty_idle_log "ERRR: cannot write activity file $TERMTTY_IDLE_ACTIVITY_FILE"
        exit 1
    }
fi

termtty_idle_log "starting termtty_watcher: timeout=${TERMTTY_IDLE_TIMEOUT}s once=${TERMTTY_IDLE_ONCE_FLAG} file=${TERMTTY_IDLE_ACTIVITY_FILE}"
termtty_idle_log "will run: $TERMTTY_IDLE_CMD"

alive=1
trap 'alive=0' INT TERM

FIRED_ONCE=0

while [ "$alive" -eq 1 ]; do
    #= current epoch seconds
    now="$(date +%s)"
    last="$(cat "$TERMTTY_IDLE_ACTIVITY_FILE" 2>/dev/null || echo "$now")"

    #= compute delta
    # shellcheck disable=SC2039
    delta=$(( now - last ))

    if [ "$delta" -ge "$TERMTTY_IDLE_TIMEOUT" ]; then
        if [ "$TERMTTY_IDLE_ONCE_FLAG" -eq 1 ] && [ "$FIRED_ONCE" -eq 1 ]; then
            #= already fired once, we can just idle sleep
            :
        else
            termtty_idle_log "idle threshold reached (delta=${delta}s >= ${TERMTTY_IDLE_TIMEOUT}s); executing command."
            #= exec via 'sh -c' so args/quotes work
            sh -c "$TERMTTY_IDLE_CMD" &
            CMD_PID=$!
            termtty_idle_log "spawned PID $CMD_PID"
            FIRED_ONCE=1

            if [ "$TERMTTY_IDLE_ONCE_FLAG" -eq 1 ]; then
                termtty_idle_log "once flag set; exiting watcher."
                break
            fi

            #= after firing, reset activity timestamp to now so we don't hammer
            date +%s >"$TERMTTY_IDLE_ACTIVITY_FILE" 2>/dev/null
        fi
    fi

    #= poll interval (seconds)
    sleep 1
done

termtty_idle_log "watcher exiting."
exit 0
