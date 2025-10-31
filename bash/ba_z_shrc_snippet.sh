
#!/usr/bin/env sh

#= file: ~/.config/{ba,z}sh/termtty_idle_watcher_rc.sh

#= ---- [ enable gate ] --------------------------------------------------------------------------
#= Allow user to disable globally or per session:
#=   export TERMTTY_IDLE_ENABLED=0
if [ "${TERMTTY_IDLE_ENABLED:-1}" = "0" ]; then
	return 0 2>/dev/null || exit 0
fi


#= ---- [ env setup ]-----------------------------------------------------------------------------
export TERMTTY_IDLE_WATCHER_ACTFILE="${HOME:-~}/.termtty_idle_watcher_act.$(id -u 2>/dev/null || echo $$)"
export TERMTTY_IDLE_WATCHER_BIN="${XDG_BIN_HOME}/termtty_idle_watcher_core.sh"
export TERMTTY_IDLE_WATCHER_CMD="${TERMTTY_IDLE_WATCHER_CMD}:-echo 'TERMTTY IDLE ACTION TRIGGERED'}"
export TERMTTY_IDLE_WATCHER_ENABLE=1
export TERMTTY_IDLE_WATCHER_ONCE="${TERMTTY_IDLE_WATCHER_ONCE:-0}"
export TERMTTY_IDLE_WATCHER_PIDFILE="${TERMTTY_IDLE_WATCHER_PIDFILE:-${HOME:-~}/.termtty_idle_watcher_pid.$(id -u 2>/dev/null || echo $$)}"
export TERMTTY_IDLE_WATCHER_TIMEOUT="${TERMTTY_IDLE_WATCHER_TIMEOUT:-300}"

termtty_idle_watcher_touch() {
	date +%s > "${TERMTTY_IDLE_WATCHER_ACTFILE}" 2>/dev/null
}


#= ---- [ prompt hooks ]--------------------------------------------------------------------------
if [ -n "${BASH_VERSION}" ]; then
	trap 'termtty_idle_watcher_touch' DEBUG
	PROMPT_COMMAND='termtty_idle_watcher_touch; '"${PROMPT_COMMAND}"
fi

if [ -n "${ZSH_VERSION}" ]; then
	autoload -U add-zsh-hook 2>/dev/null
	if command -v add-zsh-hook >/dev/null 2>&1; then
		add-zsh-hook precmd termtty_idle_watcher_touch
		add-zsh-hook preexec termtty_idle_watcher_touch
	fi
fi


#= ----[ autostart watcher ]----------------------------------------------------------------------
termtty_idle_watcher_start() {
	#= obey enable flag even here
	[ "${TERMTTY_IDLE_WATCHER_ENABLED:-1}" = "0" ] && return 0
	
	if [ -f "${TERMTTY_IDLE_WATCHER_PIDFILE}" ]; then
		oldpid="$(cat "${TERMTTY_IDLE_WATCHER_PIDFILE}" 2>/dev/null)"
		if [ -n "${oldpid}" ] && kill -0 "${oldpid}" 2>/dev/null; then
			return 0
		fi
	fi
	
	if [ -x "${TERMTTY_IDLE_WATCHER_BIN}" ]; then
		sh "${TERMTTY_IDLE_WATCHER_BIN}" \
		--timeout "${TERMTTY_IDLE_WATCHER_TIMEOUT}" \
		--cmd "${TERMTTY_IDLE_WATCHER_CMD}" \
		--activity "${TERMTTY_IDLE_WATCHER_ACTFILE}" \
		$( [ "${TERMTTY_IDLE_WATCHER_ONCE}" = "1" ] && echo "--once" ) \
		>>"${HOME}/.termtty_idle_watcher.log" 2>&1 &
		echo $! > "${TERMTTY_IDLE_WATCHER_PIDFILE}"
	fi
}

termtty_idle_watcher_start
