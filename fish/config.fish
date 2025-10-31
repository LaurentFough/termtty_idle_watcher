#= TERMTTY_IDLE'Activity'WATCHER
function _termtty_idle_watcher_init --description "TermTTY Idle Watcher:: init"
	#= TERMTTY_IDLE'Activity'WATCHER
	if set -q SSH_TTY
		#= Disable for remote sessions
		set -g -x TERMTTY_IDLE_WATCHER_ENABLE 0
	else
		if set -q TERMTTY_IDLE_WATCHER_ENABLE
			set -g -x TERMTTY_IDLE_WATCHER_ENABLE $TERMTTY_IDLE_WATCHER_ENABLE
		else
			set -g -x TERMTTY_IDLE_WATCHER_ENABLE 0
		end
	end
	set -g -x TERMTTY_IDLE_WATCHER_ACTFILE $HOME/.termtty_idle_watcher_act.( id -u 2>/dev/null || echo $fish_pid )
	set -g -x TERMTTY_IDLE_WATCHER_BIN "$XDG_BIN_HOME/termtty_idle_watcher_core.sh"
	set -g -x TERMTTY_IDLE_WATCHER_CMD "$XDG_CONFIG_HOME/bash/screensavers/screensaver.sh 6"
	set -g -x TERMTTY_IDLE_WATCHER_ONCE 0
	set -g -x TERMTTY_IDLE_WATCHER_TIMEOUT 10
end
_termtty_idle_watcher_init
