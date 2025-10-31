# 💤 TermTTY IDLE Watcher - Terminal Idle Watcher

A cross-shell, POSIX-compatible idle watcher that executes a command or script after a configurable period of user inactivity.
Supports **bash**, **zsh**, **fish**, and **POSIX sh** — runs quietly as a plugin or background daemon in your terminal sessions.

---
## 🚀 Features
- 🧩 **Cross-shell compatible** (`sh`, `bash`, `zsh`, `fish`)
- 🔄 **Plugin-style autostart** for Fish (`~/.config/fish/conf.d`)
- 🕓 **Configurable timeout** (`TERMTTY_IDLE_WATCHER_TIMEOUT`)
- ⚙️ **Custom idle action** (`TERMTTY_IDLE_WATCHER_CMD`)
- 🧠 **Per-user or per-TTY tracking** (uses `$UID` and optionally `tty`)
- 🪵 **Structured logging** to `~/{log/}termtty_idle_watcher.log`
- 🔒 Ideal for:
  - Auto-locking screens after inactivity
  - Clearing sensitive session data
  - Auto-running backups or status scripts

---
## 📦 Installation

Clone the repo:
```bash
git clone https://github.com/LaurentFough/termtty_idle_watcher.git
cd termtty_idle_watcher
```

Install the watcher core:
```bash
mkdir -p ~/.local/bin
cp ./bin/termtty_idle_watcher_core.sh ~/.local/bin/
chmod +x ~/.local/bin/termtty_idle_watcher_core.sh
```

Then install the shell plugin:
```bash
# Fish shell (recommended)
mkdir -p ~/.config/fish/conf.d
cp ./fish/conf.d/termtty_idle_watcher.fish ~/.config/fish/conf.d/

# Bash / Zsh
cat ./posixrc/rc_snippet.sh >> ~/.bashrc
cat ./posixrc/rc_snippet.sh >> ~/.zshrc
```

---
## ⚙️ Configuration

Set environment variables to customize behavior:

| Variable | Default | Description | Default |
|-----------|----------|-------------|-------------|
| `TERMTTY_IDLE_WATCHER_ENABLE` | `0\|1` | Enabled(1) or Disabled(0) | `1` |
| `TERMTTY_IDLE_WATCHER_TIMEOUT` | `300` | Seconds of inactivity before trigger | `300` |
| `TERMTTY_IDLE_WATCHER_CMD` | `echo IDLE ACTION TRIGGERED` | Command to execute when idle | `` |
| `TERMTTY_IDLE_WATCHER_ONCE` | `0` | If `1`, triggers once then exits | `0` |
| `TERMTTY_IDLE_WATCHER_ACTFILE` | `~/.termtty_idle_watcher_act.$UID` | Timestamp file | `~/.termtty_idle_watcher_act.$UID` |
| `TERMTTY_IDLE_WATCHER_PIDFILE` | `~/.termtty_idle_watcher_pid.$UID` | PID tracking file | `~/.termtty_idle_watcher_pid.$UID` |

### Example: lock session after 5 minutes

```bash
export TERMTTY_IDLE_WATCHER_TIMEOUT=300
export TERMTTY_IDLE_WATCHER_CMD="gnome-screensaver-command -l"
```

Or on macOS:

```bash
export TERMTTY_IDLE_WATCHER_CMD="/System/Library/CoreServices/Menu\ Extras/User.menu/Contents/Resources/CGSession -suspend"
```

---

## 🧩 Fish Integration

Place the following file in `~/.config/fish/conf.d/termtty_idle_watcher.fish`:

```fish
# Idle watcher plugin
if test -z "$TERMTTY_IDLE_WATCHER_ACTFILE"
    if test -n "$XDG_RUNTIME_DIR"
        set -gx TERMTTY_IDLE_WATCHER_ACTFILE "~/.termtty_idle_watcher_act."(id -u)
    else
        set -gx TERMTTY_IDLE_WATCHER_ACTFILE "~/.termtty_idle_watcher_act."(id -u)
    end
end

function termtty_idle_touch_activity
    date +%s > "$TERMTTY_IDLE_WATCHER_ACTFILE" ^/dev/null
end

function __termtty_idle_watch_prompt_hook --on-event fish_prompt
    termtty_idle_watcher_touch_activity
end

function __termtty_idle_watcher_preexec_hook --on-event fish_preexec
    termtty_idle_watcher_touch_activity
end

function __termtty_idle_watcher_start
    if test -f "$TERMTTY_IDLE_WATCHER_PIDFILE"
        set -l oldpid (cat "$TERMTTY_IDLE_WATCHER_PIDFILE" ^/dev/null)
        if test -n "$oldpid"; and kill -0 $oldpid ^/dev/null
            return 0
        end
    end

    if test -x "$TERMTTY_IDLE_WATCHER_BIN"
        set -l args "--timeout" "$TERMTTY_IDLE_WATCHER_TIMEOUT" "--cmd" "$TERMTTY_IDLE_WATCHER_CMD" "--activity" "$TERMTTY_IDLE_WATCHER_ACTFILE"
        if test "$TERMTTY_IDLE_WATCHER_ONCE" = "1"
            set args $args "--once"
        end
        sh "$TERMTTY_IDLE_WATCHER_BIN" $args >> "$HOME/{log/}termtty_idle_watcher.log" 2>&1 &
        echo $tsatus >"$TERMTTY_IDLE_WATCHER_PIDFILE"
    end
end

__termtty_idle_watcher_start
```

---

## 🧠 How It Works

1. Every shell updates an activity timestamp file on user interaction.
2. The background watcher polls this file.
3. If no update occurs within `TERMTTY_IDLE_WATCHER_TIMEOUT` seconds:
   - The configured command (`TERMTTY_IDLE_WATCHER_CMD`) runs.
   - Optionally, the watcher stops if `--once` is set.

---

## 🧪 Testing

To verify activity tracking:

```bash
cat $TERMTTY_IDLE_WATCHER_ACTFILE
sleep 2
ls
cat $TERMTTY_IDLE_WATCHER_ACTFILE
# Timestamp should update
```

To test idle trigger:
```bash
export TERMTTY_IDLE_WATCHER_TIMEOUT=10
export TERMTTY_IDLE_WATCHER_CMD="notify-send 'Idle Triggered'"
```
Leave the shell untouched for 10s and see the notification.

---

## 🛠 Development

This script is written in pure **POSIX sh**, making it portable across:
- macOS, Linux, BSD, WSL, BusyBox environments
- Minimal Docker containers

### Linting / Validation

```bash
shellcheck termtty_idle_watcher_core.sh
```

---

## 🧩 Integration Ideas

- **Lock session** after inactivity
- **Kill SSH agents** or **VPN sessions**
- **Run periodic status commands**
- **Trigger backups or sync jobs**

---

## 📄 License

MIT License © 2025 Laurent OF Fough  
You are free to use, modify, and distribute this software with attribution.

---

## 🧠 References

```bibtex
@manual{fish-shell-events,
  title        = {Fish Shell Event Handlers},
  organization = {fish-shell contributors},
  year         = {2024}
}

@manual{gnu-bash-manual,
  title        = {Bash Reference Manual, Section 6.9: PROMPT_COMMAND and DEBUG trap},
  organization = {GNU Project},
  year         = {2024}
}

@manual{zsh-hooks,
  title        = {Zsh: Functions and Hooks},
  organization = {zsh Development Group},
  year         = {2024}
}

@standard{posix-sh-2017,
  title        = {IEEE Std 1003.1-2017 (POSIX.1-2017)},
  organization = {The Open Group},
  year         = {2018}
}
```

---

### 🧷 Author
Maintained by Laurent OF Fough  
[GitHub Profile](https://github.com/LaurentFough)
