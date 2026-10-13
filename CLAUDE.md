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
| `starship`  | `~/.config/starship.toml` (bash prompt; `~/.bashrc` itself is not in the repo and just runs `eval "$(starship init bash)"`) |

- Install a package with `cd ~/dotfiles && stow <pkg>`. Several packages share `~/.config/hypr`, so that directory is real and its files are individual symlinks; don't let stow fold it.
- New config goes in its own package (one package per program); add files in the repo and restow, don't edit the target outside the repo.
- Commit style: `<package>: <what changed>` (e.g. `hypridle: lock 10m, dpms 11m`).

## Hyprland config notes

- `hyprland.lua` uses the Lua API: `hl.config({...})`, `hl.bind(...)`, `hl.window_rule({...})`, `hl.workspace_rule({...})`, `hl.on("hyprland.start", ...)`, dispatchers as `hl.dsp.*`. Check https://wiki.hypr.land for current syntax before writing new rules; don't use old hyprlang `windowrulev2 =` syntax in the Lua file.
- From the shell, dispatch Lua: `hyprctl dispatch 'hl.dsp.dpms({action = "on"})'`.
- `hypridle.conf`, `hyprlock.conf` and `hyprpaper.conf` are still **hyprlang**, not Lua.
- Autostart in `hl.on("hyprland.start")` uses `uwsm app -- <cmd>` so each app gets its own systemd scope. Currently: waybar, hyprpaper, hypridle.
- **swaync and hyprpolkitagent run as systemd user services** (`systemctl --user` enabled). Never autostart them from `hyprland.lua`; that would start duplicates.
- **Workspace 5 is a floating workspace**: every window that opens on or is moved to 5 floats; windows it floated go back to tiled when they leave. It's done with a `float-ws5` window rule plus `window.open` / `window.move_to_workspace` hooks, because `float` is a static rule effect (only applied at open) and the rule's `workspace` match misses windows sent to 5 by exec or workspace rules. Other workspaces are unaffected.
  - On 5, focus is click-only: a `workspace.active` hook sets `input.follow_mouse` to 2 there and back to 1 (hover focus) elsewhere, since the option has no per-workspace form. Don't hard-code `follow_mouse` anywhere else; the `hl.config` input block's value is overridden by the hook.
  - A focused floating window on 5 is raised (`window.active` → `hl.dsp.window.alter_zorder({ mode = "top" })`).
- **ALT+Tab / ALT+SHIFT+Tab** (all workspaces): `cycle_next({ next = true/false })` on the current workspace, then `alter_zorder` top on the newly focused window.
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
- Reuse these tokens in any new config instead of inventing colors. Hyprland window borders use `ctos` (focused) and `secondary` at 60% alpha (unfocused); square corners (`rounding = 0`), 1px borders.

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

## GRUB menu and Windows (BitLocker)

- Menu: EndeavourOS (default), Advanced options (`linux` + `linux-lts`), UEFI Firmware Settings, `Windows Boot Manager (EFI BootNext)`, EndeavourOS snapshots.
- **Windows has BitLocker. It must only boot via EFI BootNext, never chainloaded by GRUB.** Two Windows Boot Managers exist in NVRAM. The real one is on the HP SSD ESP (sda1, PARTUUID `556e68b3-…`, currently Boot0000). The Toshiba one (sdc1) is a leftover.
- `/etc/default/grub` sets `GRUB_DISABLE_OS_PROBER=true` and `GRUB_DISABLE_BOOTNEXT=true`. The second turns off grub's `31_efi_bootnext`, which listed every NVRAM entry and ran os-prober.
- `/etc/grub.d/31_windows_bootnext` (no package owns it) adds the single Windows entry. It finds the entry by label + ESP PARTUUID, so it survives renumbering, and if the entry is missing it adds nothing. Its menu id is `efi-bootnext-windows`.
- The installer's `/etc/grub.d/45_eos_windows` (a chainload entry) was deleted. Never re-add it, and never enable os-prober.
- Regenerate with `sudo grub-mkconfig -o /boot/grub/grub.cfg`. A backup of the pre-cleanup state is in `~/grub-backup-2026-10-13/`.

## Suspend: masked, do not touch

`sleep.target`, `suspend.target`, `hibernate.target`, `hybrid-sleep.target` and `suspend-then-hibernate.target` are **masked**. Resuming from suspend corrupts the display or leaves it black on this NVIDIA setup. This is **unresolved**. Don't unmask, debug or "fix" suspend (NVIDIA preserve-video-memory, nvidia-suspend services, kernel params and so on) without asking the user first. hypridle's sleep hooks are kept in place for whenever suspend comes back.

## Working in this repo

- `sudo` needs a password; ask the user to run privileged commands (`! sudo ...`).
- Reload Hyprland with `hyprctl reload`. Check for config errors with `hyprctl configerrors`.
- Restart user services with `systemctl --user restart <unit>`. Restart waybar with `pkill waybar; uwsm app -- waybar &`.
