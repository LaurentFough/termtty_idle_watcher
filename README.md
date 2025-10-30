# 💤 TermTTY - Terminal Idle Watcher

A cross-shell, POSIX-compatible idle watcher that executes a command or script after a configurable period of user inactivity.
Supports **bash**, **zsh**, **fish**, and **POSIX sh** — runs quietly as a plugin or background daemon in your terminal sessions.

---
## 🚀 Features
- 🧩 **Cross-shell compatible** (`sh`, `bash`, `zsh`, `fish`)
- 🔄 **Plugin-style autostart** for Fish (`~/.config/fish/conf.d`)
- 🕓 **Configurable timeout** (`TERMTTY_IDLE_TIMEOUT`)
- ⚙️ **Custom idle action** (`TERMTTY_IDLE_CMD`)
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
cat ./bash/bashrc_snippet.sh >> ~/.bashrc
cat ./zsh/zshrc_snippet.zsh >> ~/.zshrc
```

---
## ⚙️ Configuration

Set environment variables to customize behavior:

| Variable | Default | Description |
|-----------|----------|-------------|
| `TERMTTY_IDLE_TIMEOUT` | `300` | Seconds of inactivity before trigger |
| `TERMTTY_IDLE_CMD` | `echo IDLE ACTION TRIGGERED` | Command to execute when idle |
| `TERMTTY_IDLE_ONCE` | `0` | If `1`, triggers once then exits |
| `TERMTTY_IDLE_ACTIVITY_FILE` | `~/.termtty_idle_watcher_activity.$UID` | Timestamp file |
| `TERMTTY_IDLE_PID_FILE` | `~/.termtty_idle_watcher_pid.$UID` | PID tracking file |

### Example: lock session after 5 minutes

```bash
export TERMTTY_IDLE_TIMEOUT=300
export TERMTTY_IDLE_CMD="gnome-screensaver-command -l"
```

Or on macOS:

```bash
export TERMTTY_IDLE_CMD="/System/Library/CoreServices/Menu\ Extras/User.menu/Contents/Resources/CGSession -suspend"
```

---

## 🧩 Fish Integration

Place the following file in `~/.config/fish/conf.d/termtty_idle_watcher.fish`:

```fish
# Idle watcher plugin
if test -z "$TERMTTY_IDLE_ACTIVITY_FILE"
    if test -n "$XDG_RUNTIME_DIR"
        set -gx TERMTTY_IDLE_ACTIVITY_FILE "~/.termtty_idle_watcher_activity."(id -u)
    else
        set -gx TERMTTY_IDLE_ACTIVITY_FILE "~/.termtty_idle_watcher_activity."(id -u)
    end
end

function termtty_idle_touch_activity
    date +%s > "$TERMTTY_IDLE_ACTIVITY_FILE" ^/dev/null
end

function __termtty_idle_watch_prompt_hook --on-event fish_prompt
    termtty_idle_touch_activity
end

function __termtty_idle_watch_preexec_hook --on-event fish_preexec
    termtty_idle_touch_activity
end

function __termtty_idle_watcher_start
    if test -f "$TERMTTY_IDLE_PID_FILE"
        set -l oldpid (cat "$TERMTTY_IDLE_PID_FILE" ^/dev/null)
        if test -n "$oldpid"; and kill -0 $oldpid ^/dev/null
            return 0
        end
    end

    if test -x "$TERMTTY_IDLE_WATCH_BIN"
        set -l args "--timeout" "$IDLE_TIMEOUT" "--cmd" "$TERMTTY_IDLE_CMD" "--activity" "$TERMTTY_IDLE_ACTIVITY_FILE"
        if test "$TERMTTY_IDLE_ONCE" = "1"
            set args $args "--once"
        end
        sh "$TERMTTY_IDLE_WATCH_BIN" $args >> "$HOME/{log/}termtty_idle_watcher.log" 2>&1 &
        echo $last_pid > "$IDLE_PID_FILE"
    end
end

__termtty_idle_watcher_start
```

---

## 🧠 How It Works

1. Every shell updates an activity timestamp file on user interaction.
2. The background watcher polls this file.
3. If no update occurs within `TERMTTY_IDLE_TIMEOUT` seconds:
   - The configured command (`TERMTTY_IDLE_CMD`) runs.
   - Optionally, the watcher stops if `--once` is set.

---

## 🧪 Testing

To verify activity tracking:

```bash
cat $TERMTTY_IDLE_ACTIVITY_FILE
sleep 2
ls
cat $TERMTTY_IDLE_ACTIVITY_FILE
# Timestamp should update
```

To test idle trigger:
```bash
export TERMTTY_IDLE_TIMEOUT=10
export TERMTTY_IDLE_CMD="notify-send 'Idle Triggered'"
```
Leave the shell untouched for 10s and see the notification.

---

## 🛠 Development

This script is written in pure **POSIX sh**, making it portable across:
- macOS, Linux, BSD, WSL, BusyBox environments
- Minimal Docker containers

### Linting / Validation

```bash
shellcheck idle_watch_core.sh
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
