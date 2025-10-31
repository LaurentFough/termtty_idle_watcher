#= file: ~/.config/fish/conf.d/termtty_idle_watcher.fish

#= Fish integration for termtty_idle_watcher_core.sh
#= Responsibilities:
#=   - define $TERMTTY_IDLE_ACTIVITY_FILE
#=   - update last-activity timestamp on prompt draw & before each command
#=   - auto-start the watcher daemon if not already running


#= ---- enable gate ----------------------------------------------------
#= Allow user to disable from config.fish:
#=   set -gx TERMTTY_IDLE_WATCHER_ENABLED 0
if set -q TERMTTY_IDLE_WATCHER_ENABLE
    if test "$TERMTTY_IDLE_WATCHER_ENABLE" = "0"
        #= feature disabled; do NOT install hooks or start watcher
        exit
    end
end
#= if TERMTTY_IDLE_WATCHER_ENABLE is unset -> default is enabled


#= ----[ config / env ]-------------------------------------------------
#= set global path to activity file (shared with bash/zsh)
if not set -q TERMTTY_IDLE_WATCHER_ACTFILE
    if test -d $HOME
        set -g -x TERMTTY_IDLE_WATCHER_ACTFILE ~/.termtty_idle_watcher_act.( id -u )
    else
        set -g -x TERMTTY_IDLE_WATCHER_ACTFILE ~/.termtty_idle_watcher_act.( id -u )
    end
end

#= path to PID file for watcher
if not set -q TERMTTY_IDLE_WATCHER_PIDFILE
    if test -n $HOME
        set -g -x TERMTTY_IDLE_WATCHER_PIDFILE ~/.termtty_idle_watcher_pid.(id -u)
    else
        set -g -x TERMTTY_IDLE_WATCHER_PIDFILE ~/.termtty_idle_watcher_pid.(id -u)
    end
end

#= default idle behavior (you can override in your env before fish launches)
if not set -q TERMTTY_IDLE_WATCHER_TIMEOUT
    set -g -x TERMTTY_IDLE_WATCHER_TIMEOUT 60
end

if not set -q TERMTTY_IDLE_WATCHER_CMD
    #= NOTE: wrap in single string; watcher runs via `sh -c "$TERMTTY_IDLE_WATCHER_CMD"`
    set -g -x TERMTTY_IDLE_WATCHER_CMD "echo IDLE ACTION TRIGGERED"
    #set -g -x TERMTTY_IDLE_WATCHER_CMD "$XDG_CONFIG_HOME/bash/screensavers/screensaver.sh 6"
end

if not set -q TERMTTY_IDLE_WATCHER_ONCE
    #= 0 = can trigger repeatedly, 1 = only trigger first time then exit
    set -g -x TERMTTY_IDLE_WATCHER_ONCE 0
end

#= path to watcher core script
#= = you should `chmod +x ~/.local/bin/termtty_idle_watcher_core.sh`
if not set -q TERMTTY_IDLE_WATCHER_BIN
    set -g -x TERMTTY_IDLE_WATCHER_BIN $XDG_BIN_HOME/termtty_idle_watcher_core.sh
end


#= ----[ helper: write timestamp ]--------------------------------------
function termtty_idle_touch_activity --description "TermTTY Idle Watcher:: update,touch activity file"
    #= write "epoch seconds" to the shared activity file
    date +%s >"$TERMTTY_IDLE_WATCHER_ACTFILE" 2>/dev/null
end


#= ----[ hook: on prompt render ]---------------------------------------
#= Fish 3.x emits the event `fish_prompt` right BEFORE showing the prompt.
#= Using --on-event means we DO NOT replace your fish_prompt function.
#= So your prompt stays intact.
functions -q __termtty_idle_watcher_prompt_hook
or function __termtty_idle_watcher_prompt_hook --on-event fish_prompt --description "TermTTY Idle Watcher:: prompt hook"
    termtty_idle_touch_activity
end


#= ----[ hook: before running any command ]-----------------------------
#= Fish emits `fish_preexec` before executing a command line.
#= We touch activity here too because some workflows don't redraw prompt often
#= (e.g. long loops, fzf, etc.).
functions -q __termtty_idle_watcher_preexec_hook
or function __termtty_idle_watcher_preexec_hook --on-event fish_preexec --description "TermTTY Idle Watcher:: preexec hook"
    termtty_idle_touch_activity
end


#= ----[ autostart watcher process ]------------------------------------
#= termtty_idle_watcher autostart
function __termtty_idle_watcher_start --description "TermTTY Idle Watcher:: start termtty_idle_watcher_core.sh daemon if not running"
    #= obey enable flag *also* here in case this function is called manually
    if test -n "$TERMTTY_IDLE_WATCHER_ENABLE"
        if test "$TERMTTY_IDLE_WATCHER_ENABLE" = "0"
            return 0
        end
    end

    #= if pidfile exists and proc is alive, do nothing
    if test -f "$TERMTTY_IDLE_WATCHER_PIDFILE"
        set -l termtty_idle_watcher_pid_old ( cat $TERMTTY_IDLE_WATCHER_PIDFILE 2>/dev/null )
        if [ -n "$termtty_idle_watcher_pid_old" ] && kill -0 "$termtty_idle_watcher_pid_old" 2>/dev/null
            return 0
        end
    end
    
    #= spawn watcher in background if script exists and is executable
    if test -x "$TERMTTY_IDLE_WATCHER_BIN"
        #= build arg list
        set -l args "--timeout" "$TERMTTY_IDLE_WATCHER_TIMEOUT" \
                    "--cmd" "$TERMTTY_IDLE_WATCHER_CMD" \
                    "--activity-file" "$TERMTTY_IDLE_WATCHER_ACTFILE"

        if test "$TERMTTY_IDLE_WATCHER_ONCE" = "1"
            set args $args "--once"
        end

        #= redirect stdout+stderr to log, not /dev/null, so we can debug.
        #= change ~/log/termtty_idle_watcher.log -> /dev/null if you want silence.
        sh "$TERMTTY_IDLE_WATCHER_BIN" $args | tee -a "$HOME/log/termtty_idle_watcher.log" 2>&1 &
        set -l termtty_idle_watcher_pid $status #$last_pid
        echo $termtty_idle_watcher_pid >"$TERMTTY_IDLE_WATCHER_PIDFILE"
    end
end


#= ----[ test watcher process ]------------------------------------
#= termtty_idle_watcher test
function _termtty_idle_watcher_test --description "TermTTY Idle Watcher:: test"
    set -g -x TERMTTY_IDLE_WATCHER_ACTFILE $HOME/.termtty_idle_watcher_act.( id -u 2>/dev/null || echo $fish_pid )
    set -g -x TERMTTY_IDLE_WATCHER_BIN "$XDG_BIN_HOME/termtty_idle_watcher_core.sh"
    set -g -x TERMTTY_IDLE_WATCHER_ENABLE 1
    set -g -x TERMTTY_IDLE_WATCHER_TIMEOUT 5
    #set -g -x TERMTTY_IDLE_WATCHER_CMD 'sleep 300'
    set -g -x TERMTTY_IDLE_WATCHER_CMD "$XDG_CONFIG_HOME/bash/screensavers/screensaver.sh 3"
    set -g -x TERMTTY_IDLE_WATCHER_ONCE 1
    env | rg TERMTTY_IDLE_WATCHER_ | gsort && __termtty_idle_watcher_start
    #= • wait 5s → watcher will spawn a sleep 300
    #= • press Ctrl-C → watcher should log “killing child pid …” and both should be gone
    #= • verify: `ps aux | grep sleep | grep 300`
end


#= call it now so the watcher comes up when fish starts
__termtty_idle_watcher_start
