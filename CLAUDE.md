# dotfiles

Personal desktop config for one machine. Read this before touching anything.

## System

- **OS:** EndeavourOS (Arch), root on btrfs (`@` subvolume), GRUB.
- **GPU:** NVIDIA GTX 1660 Ti (TU116), `nvidia-open` driver (615.x). `nvidia_drm` modeset and fbdev are on (driver defaults, no modprobe.d file).
- **Kernels:** both `linux` and `linux-lts` are installed, each with its own headers and matching NVIDIA module: `nvidia-open` (for `linux`) and `nvidia-open-lts` (for `linux-lts`). Keep the pairs in sync on upgrades. A kernel without its matching NVIDIA module boots with no working display.
- **Compositor:** Hyprland 0.56, **Lua config** (`hyprland.lua`, not `hyprland.conf`), launched through **uwsm** (`hyprland-uwsm.desktop`).
- **System disk:** `sdb` = Kingston SA400 480G (`/`, `/home`, `/boot/efi`, swap) on `ata5`. 2026-10-14: SATA CRC errors (`ata5 … BadCRC/ICRC`, SMART 199 = 30, all device-to-host reads) traced to its cable (tight, routed under the GPU); 199/218 reached 72 before the fix. **Fixed 2026-10-15:** the drive now sits in the SSD tray next to the HP with nothing pressing on its cable (still `ata5`); no `ata5` errors since, and `btrfs scrub` was clean. NAND fine: 170 = 0/35 and life 93%, same as 2026-10-12. Baseline is **199/218 = 72**; if it rises or `ata5` errors return, check the cable/port again. Timeshift snapshots live on this same disk; they are not a backup.
- **Login:** greetd with the ctOS greeter (Quickshell in cage); plasma-login is installed but disabled. See "Display manager (greetd)".

## Stow layout

The repo lives at `~/dotfiles`. Each top-level directory is a stow package that mirrors `$HOME`:

| package     | provides                                              |
|-------------|-------------------------------------------------------|
| `hypr`      | `~/.config/hypr/hyprland.lua`                         |
| `hypridle`  | `~/.config/hypr/hypridle.conf`                        |
| `hyprlock`  | `~/.config/hypr/hyprlock.conf`                        |
| `hyprpaper` | `~/.config/hypr/hyprpaper.conf`, `~/.config/hypr/wallpapers/` |
| `waybar`    | `~/.config/waybar/` (`config.jsonc`, `style.css`, `scripts/ctos-*`), see "Waybar" below |
| `rofi`      | `~/.config/rofi/` (`ctos.rasi` theme)                 |
| `kitty`     | `~/.config/kitty/kitty.conf`, `themes/monoglow_z.conf` |
| `fastfetch` | `~/.config/fastfetch/` (dedsec logo)                  |
| `starship`  | `~/.config/starship.toml` (bash prompt; `~/.bashrc` itself is not in the repo and just runs `eval "$(starship init bash)"`) |
| `grub`      | **not a stow package** (`.stow-local-ignore` makes `stow grub` a no-op). ctOS GRUB theme source; built with `grub/build.sh` and copied to `/boot/grub/themes/ctos`, see "GRUB theme" below |
| `greetd`    | **not a stow package** (same `.stow-local-ignore` trick). greetd configs and ctOS greeter config, copied to `/etc/greetd`, `/etc/ctos`, `/var/lib/ctos`, see "Display manager (greetd)" below |

- Install a package with `cd ~/dotfiles && stow <pkg>`. Several packages share `~/.config/hypr`, so that directory is real and its files are individual symlinks; don't let stow fold it.
- New config goes in its own package (one package per program); add files in the repo and restow, don't edit the target outside the repo.
- Commit style: `<package>: <what changed>` (e.g. `hypridle: lock 10m, dpms 11m`).

## Hyprland config notes

- `hyprland.lua` uses the Lua API: `hl.config({...})`, `hl.bind(...)`, `hl.window_rule({...})`, `hl.workspace_rule({...})`, `hl.on("hyprland.start", ...)`, dispatchers as `hl.dsp.*`. Check https://wiki.hypr.land for current syntax before writing new rules; don't use old hyprlang `windowrulev2 =` syntax in the Lua file.
- From the shell, dispatch Lua: `hyprctl dispatch 'hl.dsp.dpms({action = "on"})'`.
- `hypridle.conf`, `hyprlock.conf` and `hyprpaper.conf` are still **hyprlang**, not Lua.
- Autostart in `hl.on("hyprland.start")` uses `uwsm app -- <cmd>` so each app gets its own systemd scope. Currently: waybar, hyprpaper, hypridle.
- **swaync and hyprpolkitagent run as systemd user services** (`systemctl --user` enabled). Never autostart them from `hyprland.lua`; that would start duplicates.
- **SUPER+R** (rofi) is `non_consuming` and runs `pgrep -x rofi || rofi -show drun`: when rofi is already open nothing new starts, the key passes through, and rofi's `kb-mode-next` includes `Super+r`, so it cycles LAUNCH → EXEC → PROC → LAUNCH. Esc closes. Keep the bind non-consuming, or the key never reaches rofi.
- `misc.allow_session_lock_restore = true` is required for the lock-screen recovery below. Keep it.

## Waybar

- Waybar 0.15, one bar at the **top**. Custom modules are driven by scripts in `waybar/.config/waybar/scripts/` (stowed with the package):
  - `ctos-ws`: the five workspace cells. `ctos-ws listen` is one shared listener (a single `socat` on Hyprland's `.socket2.sock`) that writes `$XDG_RUNTIME_DIR/ctos-ws.state` and sends Waybar SIGRTMIN+8; the cells (`ctos-ws cell N`) only read that file. Waybar starts and stops the listener through the hidden `custom/ws-listen` module, so it is never autostarted.
  - `ctos-meter cpu|mem`: CPU/MEM value with a thin fill bar.
  - `ctos-net`: `[NW_xxxx]` tag, green dot online, red dot and `[NW_----]` offline (`CTOS_NET_ROUTE` fakes the route for testing).
  - `ctos-mic`: mic indicator, empty (so Waybar hides it) unless the default mic is muted (red) or an app records from a real input (green; monitor sources and pavucontrol meters ignored). Click mutes the mic and sends SIGRTMIN+9.
- Right end: `custom/mic`, then the built-in `wireplumber` (icon + `NN%`, red when muted; scroll ±5 capped at 100, click mutes, right-click pavucontrol) and `clock` (`[YYYY-MM-DD // HH:MM]`, weekday in the tooltip).
- GTK tooltips eat one scroll step when the tooltip is visible: scrolling the volume with long pauses between notches skips every other one; normal wheel speed is fine. Not a config bug.
- **Waybar 0.15 vs Hyprland Lua dispatch:** Waybar's built-in `hyprland/workspaces` (and any `hyprctl dispatch workspace N` / `workspace e±1`) sends hyprlang-style dispatches, which Hyprland 0.56 with the Lua config rejects, so clicks and scrolls do nothing. Don't switch back to the built-in module; dispatch Lua instead, e.g. `hyprctl dispatch 'hl.dsp.focus({ workspace = 3 })'` (what `ctos-ws focus N` / `scroll prev|next` do). Same for any other Waybar `on-click` that dispatches to Hyprland.

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

The graphical session is on **tty1** (greetd `vt = 1`).

1. Ctrl+Alt+F2 and log in on the console.
2. If hyprlock **hung**: `pkill -USR1 hyprlock` (SIGUSR1 unlocks).
   If hyprlock **crashed** (red "lockscreen died" screen): `hyprctl --instance 0 dispatch 'hl.dsp.exec_cmd("hyprlock")'` (needs `allow_session_lock_restore`).
   Last resort, loses the session: `hyprctl --instance 0 dispatch 'hl.dsp.exit()'`.
3. Ctrl+Alt+F1 to go back.

## Display manager (greetd)

- **greetd** (`greetd.service`, aliased `display-manager.service`) on tty1 runs the ctOS greeter as user `greeter`: `env CTOS_MODE=kiosk cage -s -d -- sh -c 'exec quickshell --path /opt/ctos/greeter.qml >/var/lib/ctos/greeter.log 2>&1'`. Quickshell's output, including the greetd hand-off (`Session launched. Exiting Greeter: pkill -x cage`), goes to `/var/lib/ctos/greeter.log` (rewritten each greeter start) instead of tty1; read it first when the greeter misbehaves. `cage -s` keeps Ctrl+Alt+Fn working; recovery depends on it. The launch command reaches greetd joined with spaces and run through `sh`, so launch arguments can't contain spaces.
- The greeter code is the ctOS fork `~/ctOS` (`github.com/jihedr/ctOS`), rsynced to `/opt/ctos`. Change the code in the fork (commits there), then re-sync: `sudo rsync -ahq --exclude=.git --exclude=.assets --chown=root:root --chmod=Du=rwx,Dg=rx,Do=rx,Fu=rw,Fg=r,Fo=r ~/ctOS/ /opt/ctos/`. Don't use the fork's `install.sh` (interactive wizard, writes its own config).
- Config source is `greetd/` in this repo:
  - `etc/greetd/ctos.toml` and `agreety.toml` go in `/etc/greetd/`. `/etc/greetd/config.toml` is a **symlink** to one of them.
  - `etc/ctos/greeter.config.json` goes in `/etc/ctos/`. It sets the fake identity/status and `launchOverride` (= the `hyprland-uwsm.desktop` Exec).
  - `var/lib/ctos/greeter.state.json` goes in `/var/lib/ctos/`, owned by `greeter`; the greeter rewrites it.
  - Install a change with `sudo install -m644 ~/dotfiles/greetd/etc/... /etc/...`, then `sudo systemctl restart greetd`. Restarting greetd kills a session started from it, so restart from a tty, not from Hyprland.
- Test without root inside Hyprland: `CTOS_DEBUG=1 CTOS_MODE=test CTOS_CONFIG=$HOME/dotfiles/greetd/etc/ctos/greeter.config.json quickshell --path ~/ctOS/greeter.qml` (password `password`, Esc quits). For real greetd on VT5 without touching the display manager: `sudo greetd --config ~/dotfiles/greetd/staging.toml`. That needs `/etc/ctos/greeter.staging.json`; remove it afterwards.
- The greeter doesn't unlock KWallet (plasma-login's PAM did via `pam_kwallet5`).
- Pre-switch snapshot: Timeshift "before greetd/ctOS greeter".

### Login recovery

Do these from a console: **Ctrl+Alt+F2**, log in as jihed.

- **A. ctOS greeter broken, use the text login (agreety):**
  `sudo ln -sf agreety.toml /etc/greetd/config.toml && sudo systemctl restart greetd`, then Ctrl+Alt+F1 to log in.
  Undo: `sudo ln -sf ctos.toml /etc/greetd/config.toml && sudo systemctl restart greetd`.
- **B. Back to plasma-login:**
  `sudo systemctl disable greetd && sudo systemctl enable plasmalogin && sudo reboot`.
  Undo: `sudo systemctl disable plasmalogin && sudo systemctl enable greetd && sudo reboot`.
- **C. No console reachable** (Ctrl+Alt+F2 does nothing): hard reboot. In GRUB press `e` on EndeavourOS, add `systemd.unit=multi-user.target` at the end of the `linux` line, then Ctrl+X. The machine boots to a text login with no display manager; log in and run A or B.
- **D. Last resort:** in GRUB, pick "EndeavourOS snapshots" and boot the "before greetd/ctOS greeter" snapshot.

## Snapshots

- **Timeshift** in btrfs mode: daily (keep 5) and boot (keep 3) snapshots.
- **grub-btrfsd** is enabled with an override (`/etc/systemd/system/grub-btrfsd.service.d/override.conf`) running `--timeshift-auto`, so new Timeshift snapshots show up as bootable GRUB entries.
- Take a manual snapshot (`sudo timeshift --create --comments "..."`) before risky system changes (driver, kernel, display manager).

## GRUB menu and Windows (BitLocker)

- Menu: EndeavourOS (default), Advanced options (`linux` + `linux-lts`), UEFI Firmware Settings, `Windows Boot Manager (EFI BootNext)`, EndeavourOS snapshots.
- **Windows has BitLocker. It must only boot via EFI BootNext, never chainloaded by GRUB.** Two Windows Boot Managers exist in NVRAM. The real one is on the HP SSD ESP (sda1, PARTUUID `556e68b3-…`, currently Boot0000). The Toshiba one (sdc1) is a leftover.
- Kernel command line (`GRUB_CMDLINE_LINUX_DEFAULT`): `nowatchdog nvme_load=YES resume=UUID=5d22b442-… quiet loglevel=3 systemd.show_status=auto rd.udev.log_level=3`. The last four give a **quiet boot** (applied 2026-10-15): GRUB goes straight to the greeter. systemd still prints failures, and `journalctl -b` keeps everything. To see boot text once: `e` in GRUB, delete `quiet`, Ctrl+X. Revert: `sudo cp /etc/default/grub.pre-quiet /etc/default/grub && sudo grub-mkconfig -o /boot/grub/grub.cfg`.
- `/etc/default/grub` sets `GRUB_TIMEOUT=10` (menu style), `GRUB_DISABLE_OS_PROBER=true` and `GRUB_DISABLE_BOOTNEXT=true`. The second turns off grub's `31_efi_bootnext`, which listed every NVRAM entry and ran os-prober.
- `/etc/grub.d/31_windows_bootnext` (no package owns it) adds the single Windows entry. It finds the entry by label + ESP PARTUUID, so it survives renumbering, and if the entry is missing it adds nothing. Its menu id is `efi-bootnext-windows`.
- The installer's `/etc/grub.d/45_eos_windows` (a chainload entry) was deleted. Never re-add it, and never enable os-prober.
- Regenerate with `sudo grub-mkconfig -o /boot/grub/grub.cfg`. A backup of the pre-cleanup state is in `~/grub-backup-2026-10-13/`.

### GRUB theme

- ctOS theme at `/boot/grub/themes/ctos`, enabled by `GRUB_THEME="/boot/grub/themes/ctos/theme.txt"` in `/etc/default/grub` (the only line the theme changed there). `GRUB_BACKGROUND` (EndeavourOS splash) is still set; `00_header` ignores it while `GRUB_THEME` is set and uses it again if the theme is removed. The theme doesn't touch menu entries or the Windows BootNext setup.
- Source: `grub/theme.txt` + `grub/build.sh`, which writes `grub/build/ctos/` (gitignored): `ctos-v2.png` at 1920x1080, 1x1 9-slice PNGs, and JetBrains Mono `.pf2` fonts. `build.sh` prints the font names; `theme.txt` must use them exactly (`JetBrainsMono NFM Regular 12/18`, `JetBrainsMono NFM Light Regular 24`).
- GRUB can't read `$HOME` (separate subvolume), so the theme is **copied**, not stowed. Update: `grub/build.sh`, then `sudo install -m 644 ~/dotfiles/grub/build/ctos/* /boot/grub/themes/ctos/`. No `grub-mkconfig` needed unless a `.pf2` is added, removed or renamed (`00_header` writes a `loadfont` line per `.pf2`). Never `grub-install` for theme changes.
- Pre-theme backup (`/etc/default/grub`, `grub.cfg`): `~/grub-backup-2026-10-13-theme/`.
- **Revert**: `sudo cp ~/grub-backup-2026-10-13-theme/grub /etc/default/grub && sudo grub-mkconfig -o /boot/grub/grub.cfg` (or comment out `GRUB_THEME`); optionally `sudo rm -r /boot/grub/themes/ctos`. If the menu is unreadable at boot, wait: the default entry still boots after the 10 s timeout. For another entry, press `c`, run `terminal_output console`, Esc (plain text menu). For Windows, the firmware's one-time boot menu (real Windows Boot Manager on the HP SSD) avoids GRUB entirely.

## Suspend: masked, do not touch

`sleep.target`, `suspend.target`, `hibernate.target`, `hybrid-sleep.target` and `suspend-then-hibernate.target` are **masked**. Resuming from suspend corrupts the display or leaves it black on this NVIDIA setup. This is **unresolved**. Don't unmask, debug or "fix" suspend (NVIDIA preserve-video-memory, nvidia-suspend services, kernel params and so on) without asking the user first. hypridle's sleep hooks are kept in place for whenever suspend comes back.

## Working in this repo

- `sudo` needs a password; ask the user to run privileged commands (`! sudo ...`).
- Reload Hyprland with `hyprctl reload`. Check for config errors with `hyprctl configerrors`.
- Restart user services with `systemctl --user restart <unit>`. Restart waybar with `pkill waybar; uwsm app -- waybar &`.
