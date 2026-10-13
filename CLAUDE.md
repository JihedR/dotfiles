# dotfiles

Personal desktop config for one machine. Read this before touching anything.

## System

- **OS:** EndeavourOS (Arch), root on btrfs (`@` subvolume), GRUB.
- **GPU:** NVIDIA GTX 1660 Ti (TU116), `nvidia-open` driver (615.x). `nvidia_drm` modeset and fbdev are on (driver defaults, no modprobe.d file).
- **Kernels:** both `linux` and `linux-lts` are installed, each with its own headers and matching NVIDIA module: `nvidia-open` (for `linux`) and `nvidia-open-lts` (for `linux-lts`). Keep the pairs in sync on upgrades. A kernel without its matching NVIDIA module boots with no working display.
- **Compositor:** Hyprland 0.56, **Lua config** (`hyprland.lua`, not `hyprland.conf`), launched through **uwsm** (`hyprland-uwsm.desktop`).

## Stow layout

The repo lives at `~/dotfiles`. Each top-level directory is a stow package that mirrors `$HOME`:

| package     | provides                                              |
|-------------|-------------------------------------------------------|
| `hypr`      | `~/.config/hypr/hyprland.lua`                         |
| `hypridle`  | `~/.config/hypr/hypridle.conf`                        |
| `hyprlock`  | `~/.config/hypr/hyprlock.conf`                        |
| `hyprpaper` | `~/.config/hypr/hyprpaper.conf`, `~/.config/hypr/wallpapers/` |
| `waybar`    | `~/.config/waybar/`                                   |
| `rofi`      | `~/.config/rofi/` (`ctos.rasi` theme)                 |
| `kitty`     | `~/.config/kitty/kitty.conf`, `themes/monoglow_z.conf` |
| `fastfetch` | `~/.config/fastfetch/` (dedsec logo)                  |

- Install a package with `cd ~/dotfiles && stow <pkg>`. Several packages share `~/.config/hypr`, so that directory is real and its files are individual symlinks; don't let stow fold it.
- New config goes in its own package (one package per program); add files in the repo and restow, don't edit the target outside the repo.
- Commit style: `<package>: <what changed>` (e.g. `hypridle: lock 10m, dpms 11m`).

## Hyprland config notes

- `hyprland.lua` uses the Lua API: `hl.config({...})`, `hl.bind(...)`, `hl.window_rule({...})`, `hl.workspace_rule({...})`, `hl.on("hyprland.start", ...)`, dispatchers as `hl.dsp.*`. Check https://wiki.hypr.land for current syntax before writing new rules; don't use old hyprlang `windowrulev2 =` syntax in the Lua file.
- From the shell, dispatch Lua: `hyprctl dispatch 'hl.dsp.dpms({action = "on"})'`.
- `hypridle.conf`, `hyprlock.conf` and `hyprpaper.conf` are still **hyprlang**, not Lua.
- Autostart in `hl.on("hyprland.start")` uses `uwsm app -- <cmd>` so each app gets its own systemd scope. Currently: waybar, hyprpaper, hypridle.
- **swaync and hyprpolkitagent run as systemd user services** (`systemctl --user` enabled). Never autostart them from `hyprland.lua`; that would start duplicates.
- `misc.allow_session_lock_restore = true` is required for the lock-screen recovery below. Keep it.

## ctOS style

Everything is themed after the Watch Dogs ctOS look, from `~/ctOS/common/Theme.qml` (a separate checkout of the ctOS Quickshell project, also the source of the wallpapers).

| token       | hex       | use                              |
|-------------|-----------|----------------------------------|
| `bg`        | `#0e0e0e` | backgrounds                      |
| `bg_bright` | `#202020` | raised surfaces                  |
| `ctos`      | `#d9d9d9` | main foreground, borders, CT mark |
| `text`      | `#ffffff` | primary text                     |
| `text_dim`  | `#cacaca` | dim text                         |
| `secondary` | `#7a7a7a` | dividers, labels                 |
| `accent`    | `#1bfd9c` | success / active                 |
| `error`     | `#fc3e38` | errors                           |

- Font: JetBrainsMono Nerd Font (Light for big labels). Square corners, 1px borders, uppercase labels, terse `//`-separated text. The "CT|OS" mark is a filled `ctos` block with `bg` text "CT" followed by thin "OS".
- Wallpapers: `ctos-v1.png` (centred logo), `ctos-v2.png` (small logo bottom-left, in use).
- Reuse these tokens in any new config instead of inventing colors. The Hyprland border gradient in `hyprland.lua` is still the default cyan/green and hasn't been themed yet.

## Lock and idle

- **hypridle**: lock after 10 min, DPMS off at 11 min, `before_sleep_cmd` locks, `after_sleep_cmd` turns DPMS on. `lock_cmd = pidof hyprlock || hyprlock` (single instance).
- **SUPER+L** runs `loginctl lock-session`, which goes through hypridle's `lock_cmd`. Lock through loginctl, not by calling hyprlock directly.
- **hyprlock**: ctOS lock screen (`hyprlock.conf`).

### Lock-screen recovery

The graphical session is on **tty3**.

1. Ctrl+Alt+F4 and log in on the console.
2. If hyprlock **hung**: `pkill -USR1 hyprlock` (SIGUSR1 unlocks).
   If hyprlock **crashed** (red "lockscreen died" screen): `hyprctl --instance 0 dispatch 'hl.dsp.exec_cmd("hyprlock")'` (needs `allow_session_lock_restore`).
   Last resort, loses the session: `hyprctl --instance 0 dispatch 'hl.dsp.exit()'`.
3. Ctrl+Alt+F3 to go back.

## Snapshots

- **Timeshift** in btrfs mode: daily (keep 5) and boot (keep 3) snapshots.
- **grub-btrfsd** is enabled with an override (`/etc/systemd/system/grub-btrfsd.service.d/override.conf`) running `--timeshift-auto`, so new Timeshift snapshots show up as bootable GRUB entries.
- Take a manual snapshot (`sudo timeshift --create --comments "..."`) before risky system changes (driver, kernel, display manager).

## Suspend: masked, do not touch

`sleep.target`, `suspend.target`, `hibernate.target`, `hybrid-sleep.target` and `suspend-then-hibernate.target` are **masked**. Resuming from suspend corrupts the display or leaves it black on this NVIDIA setup. This is **unresolved**. Don't unmask, debug or "fix" suspend (NVIDIA preserve-video-memory, nvidia-suspend services, kernel params and so on) without asking the user first. hypridle's sleep hooks are kept in place for whenever suspend comes back.

## Working in this repo

- `sudo` needs a password; ask the user to run privileged commands (`! sudo ...`).
- Reload Hyprland with `hyprctl reload`. Check for config errors with `hyprctl configerrors`.
- Restart user services with `systemctl --user restart <unit>`. Restart waybar with `pkill waybar; uwsm app -- waybar &`.
