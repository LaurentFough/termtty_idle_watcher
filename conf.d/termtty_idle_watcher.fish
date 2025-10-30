#= termtty_idle_watcher.fish
#= default comment indicator= '#'

#= Fish integration for termtty_idle_watcher_core.sh
#= Responsibilities:
#=   - define $TERMTTY_IDLE_ACTIVITY_FILE
#=   - update last-activity timestamp on prompt draw & before each command
#=   - auto-start the watcher daemon if not already running


#= ----[ config / env ]-------------------------------------------------
#= set global path to activity file (shared with bash/zsh)
if not set -q TERMTTY_IDLE_ACTIVITY_FILE
    if test -d $HOME
        set -g -x TERMTTY_IDLE_ACTIVITY_FILE ~/.termtty_idle_watcher_activity.( id -u )
    else
        set -g -x TERMTTY_IDLE_ACTIVITY_FILE ~/.termtty_idle_watcher_activity.( id -u )
    end
end

#= path to PID file for watcher
if not set -q TERMTTY_IDLE_PID_FILE
    if test -n $HOME
        set -g -x TERMTTY_IDLE_PID_FILE ~/.termtty_idle_watcher_pid.(id -u)
    else
        set -g -x TERMTTY_IDLE_PID_FILE ~/.termtty_idle_watcher_pid.(id -u)
    end
end

#= default idle behavior (you can override in your env before fish launches)
if not set -q TERMTTY_IDLE_TIMEOUT
    set -g -x TERMTTY_IDLE_TIMEOUT 60
end

if not set -q TERMTTY_IDLE_CMD
    #= NOTE: wrap in single string; watcher runs via `sh -c "$TERMTTY_IDLE_CMD"`
    #set -g -x TERMTTY_IDLE_CMD 'echo IDLE ACTION TRIGGERED'
    set -g -x TERMTTY_IDLE_CMD '$XDG_CONFIG_HOME/bash/screensavers/screensaver.sh 6'
end

if not set -q TERMTTY_IDLE_ONCE
    #= 0 = can trigger repeatedly, 1 = only trigger first time then exit
    set -g -x TERMTTY_IDLE_ONCE 0
end

#= path to watcher core script
#= = you should `chmod +x ~/.local/bin/termtty_idle_watcher_core.sh`
if not set -q TERMTTY_IDLE_WATCH_BIN
    set -g -x TERMTTY_DLE_WATCH_BIN $XDG_BIN_HOME/termtty_idle_watcher_core.sh
end


#= ----[ helper: write timestamp ]--------------------------------------
function termtty_idle_touch_activity --description "termtty_idle_watcher:: update,touch activity file"
    #= write "epoch seconds" to the shared activity file
    date +%s >"$TERMTTY_IDLE_ACTIVITY_FILE" 2>/dev/null
end


#= ----[ hook: on prompt render ]---------------------------------------
#= Fish 3.x emits the event `fish_prompt` right BEFORE showing the prompt.
#= Using --on-event means we DO NOT replace your fish_prompt function.
#= So your prompt stays intact.
functions -q __termtty_idle_watcher_prompt_hook
or function __termtty_idle_watcher_prompt_hook --on-event fish_prompt --description "TermTTY Idle watcher: prompt hook"
    termtty_idle_touch_activity
end


#= ----[ hook: before running any command ]-----------------------------
#= Fish emits `fish_preexec` before executing a command line.
#= We touch activity here too because some workflows don't redraw prompt often
#= (e.g. long loops, fzf, etc.).
functions -q __termtty_idle_watcher_preexec_hook
or function __termtty_idle_watcher_preexec_hook --on-event fish_preexec --description "TermTTY Idle watcher: preexec hook"
    termtty_idle_touch_activity
end



#= ----[ autostart watcher process ]------------------------------------
#= termtty_idle_watcher autostart
function __termtty_idle_watcher_start --description "termtty_idle_watcher:: start termtty_idle_watcher_core.sh daemon if not running"
    #= if pidfile exists and proc is alive, do nothing
    if test -f "$TERMTTY_IDLE_PID_FILE"
        set -l termtty_idle_watcher_pid_old ( cat $TERMTTY_IDLE_PID_FILE 2>/dev/null )
        if [ -n "$termtty_idle_watcher_pid_old" ] && kill -0 "$termtty_idle_watcher_pid_old" 2>/dev/null
            return 0
        end
    end
    
    #= spawn watcher in background if script exists and is executable
    if test -x "$TERMTTY_IDLE_WATCH_BIN"
        #= build arg list
        set -l args "--timeout" "$TERMTTY_IDLE_TIMEOUT" \
                    "--cmd" "$TERMTTY_IDLE_CMD" \
                    "--activity-file" "$TERMTTY_IDLE_ACTIVITY_FILE"

        if test "$TERMTTY_IDLE_ONCE" = "1"
            set args $args "--once"
        end

        #= redirect stdout+stderr to log, not /dev/null, so we can debug.
        #= change ~/log/termtty_idle_watcher.log -> /dev/null if you want silence.
        sh "$TERMTTY_IDLE_WATCH_BIN" $args | tee -a "$HOME/log/termtty_idle_watcher.log" 2>&1 &
        set -l termtty_idle_watcher_pid $last_pid
        echo $termtty_idle_watcher_pid >"$TERMTTY_IDLE_PID_FILE"
    end
end


#= call it now so the watcher comes up when fish starts
__termtty_idle_watcher_start
