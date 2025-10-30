#= TERMTTY_IDLE Activity Watcher
set -g -x TERMTTY_IDLE_ONCE 0
set -g -x TERMTTY_IDLE_CMD '$XDG_CONFIG_HOME/bash/screensavers/screensaver.sh 6'
set -g -x TERMTTY_IDLE_ACTIVITY_FILE $HOME/.termtty_idle_watch_activity.( id -u 2>/dev/null || echo $fish_pid )
set -g -x TERMTTY_IDLE_WATCH_BIN $XDG_BIN_HOME/termtty_idle_watch_core.sh
