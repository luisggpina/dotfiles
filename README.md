# dotfiles — Arch Linux + i3

Configs and setup notes for my Arch/i3 machines. This README is the shared
record of how they are built; each machine's hardware, disk layout and
one-off workarounds live in `hosts/<hostname>.md`.

| Host | Machine | Notes |
|---|---|---|
| `ultra` | ThinkPad X1 Carbon Gen 3 (2015) | [hosts/ultra.md](hosts/ultra.md) |

- **Desktop:** i3 (X11) · i3status-rust bar · rofi · Alacritty · tmux · zsh
- **Login:** LightDM · **Lock:** i3lock-color via xss-lock
- **Power:** TLP, charge thresholds 75–80 %, suspend-then-hibernate

---

## Contents

1. [Repo layout & usage](#1-repo-layout--usage)
2. [Hosts](#2-hosts)
3. [Base install](#3-base-install)
4. [First boot](#4-first-boot)
5. [Shell: zsh, tmux, SSH](#5-shell-zsh-tmux-ssh)
6. [Graphical session](#6-graphical-session)
7. [Keyboard](#7-keyboard)
8. [Bar: i3status-rust](#8-bar-i3status-rust)
9. [Power: TLP, battery, hibernation](#9-power-tlp-battery-hibernation)
10. [Lock screen](#10-lock-screen)
11. [Fingerprint](#11-fingerprint)
12. [Applications](#12-applications)
13. [System files checklist](#13-system-files-checklist)
14. [Open items & known issues](#14-open-items--known-issues)

---

## 1. Repo layout & usage

Managed with [GNU Stow](https://www.gnu.org/software/stow/): each top-level
folder is a "package" whose contents mirror `$HOME`. `stow <pkg>` symlinks
them into place. The repo lives at **`~/repos/dotfiles`**; a `.stowrc`
containing `--target=~` makes Stow link into `$HOME` regardless of where the
repo is (by default Stow links into the repo's *parent* directory — that bit
me once, putting every link in `~/repos/`). `--no-folding` makes Stow create
real directories (`~/.config`, `~/bin`, …) and link individual files, instead
of linking a whole directory into the repo when it doesn't exist yet —
otherwise anything an app later writes there would land in the repo.

```
~/repos/dotfiles/
├── .stowrc            ← --target=~ --no-folding
├── install.sh         ← stow packages (all, or one at a time)
├── zsh/.zshrc  zsh/.zprofile          ┐
├── tmux/.tmux.conf                    │
├── vim/.vimrc                         │
├── git/.gitconfig                     │
├── x/.Xresources                      │ shared by every host
├── i3/.config/i3/config               │
├── i3status/.config/i3status-rust/config.toml
├── rofi/.config/rofi/config.rasi      │
├── alacritty/.config/alacritty/alacritty.toml
├── dunst/.config/dunst/dunstrc        │
├── gammastep/.config/gammastep/config.ini
├── gtk/.config/gtk-{3,4}.0/settings.ini  ← GTK font (Chrome UI, §6)
├── bin/bin/{lock,git-vimdiff}
├── host-ultra/        ← only what differs on ultra (see §2)
│   ├── .Xresources.host
│   ├── .config/i3/host.conf
│   └── bin/batmode
├── system/            ← copies of /etc and /boot files — NOT stowed
│   ├── common/        ← every host
│   └── ultra/         ← this host only (boot entry, fstab, …)
├── pkgs/
│   ├── common.txt  common-aur.txt     ← every host (curated)
│   ├── ultra.txt   ultra-aur.txt      ← extras on ultra (generated)
│   └── update.sh
└── hosts/ultra.md     ← hardware notes and install record
```

Branches: **`master`** is this setup; **`legacy`** holds the previous
(2024) flat configs — Xmodmap, xbindkeys, bumblebee-status i3 config, etc.

New machine (its `host-<hostname>` package must exist first — §2):

```sh
sudo pacman -S --needed git stow
git clone git@github.com:luisggpina/dotfiles.git ~/repos/dotfiles
cd ~/repos/dotfiles
sudo pacman -S --needed - < pkgs/common.txt
sudo pacman -S --needed - < pkgs/$(uname -n).txt
yay -S --needed - < pkgs/common-aur.txt
yay -S --needed - < pkgs/$(uname -n)-aur.txt
./install.sh -n        # dry run
./install.sh
```

Porting a machine piece by piece — link packages one at a time and check
each before moving on:
```sh
./install.sh -l              # every package: linked / partial / not linked / conflict
./install.sh zsh tmux        # just these
./install.sh host            # this machine's host-<hostname>
./install.sh -D tmux         # unlink one
./install.sh -R i3           # relink after adding/removing files in a package
./install.sh -h              # usage
```
`x` and `i3` include files from the host package, so the script reminds you
to link `host` with them. A full `./install.sh` needs `host-<hostname>` to
exist; naming packages works without it.

`install.sh -D` (no package names) unlinks everything — do that **before**
pulling a commit that moves files between packages, then `./install.sh`
again afterwards. Stow refuses to overwrite existing real files (or links it
doesn't own, including dangling ones); `-l` shows those as `conflict` —
move/delete them and rerun. Check a link with `ls -la ~/.zshrc` (should
point into `repos/dotfiles/…`).

Adding a new config: create `<pkg>/<path relative to $HOME>`, move the file
there, `stow <pkg>`. Tools that rewrite their config by replacing the file
(htop, KeePassXC) are left out on purpose — they'd turn the link back into a
plain file.

Refresh package lists after installing things:

```sh
pkgs/update.sh     # writes pkgs/<host>.txt and pkgs/<host>-aur.txt
```
It records whatever is installed here and **not** in the common lists. To
share a package between hosts, move its line to `common*.txt` by hand and
rerun on each host. It also lists common packages missing on this host.

**Never commit:** SSH keys, the KeePassXC database, tokens/API keys. The repo
is public — check before pushing:

```sh
grep -rniE 'token|secret|passw|api[_-]?key|BEGIN .*PRIVATE' . --exclude-dir=.git
```

### Git identity
Commits use GitHub's no-reply address (profile email kept private):
```sh
git config --global user.name "Luís Pina"
git config --global user.email "luisggpina@users.noreply.github.com"
```
(Stored in `git/.gitconfig`.) The laptop pushes over SSH with its own
ed25519 key added to GitHub; test with `ssh -T git@github.com`.

### git diff in vimdiff
`git diff` opens each changed file side by side in vim (`:qa` → next file).
`git/.gitconfig` sets `diff.external = git-vimdiff` (the wrapper is
`bin/bin/git-vimdiff`, so `~/bin` must be on `PATH`) and `pager.diff = false`
(otherwise git pipes through `less` and vim can't take the screen).
Side effect: anything that pipes `git diff` launches vim — use
**`git difff`** (`diff --no-ext-diff`) for plain text, e.g. `git difff | xclip`.
`git diff --stat`, `git add -p`, `git log -p` and `git show` are unaffected.

---

## 2. Hosts

Shared files hold everything common; each host adds only what differs.
Every shared config that can differ ends with one include line:

| Shared file | Includes | Required in every `host-*`? |
|---|---|---|
| `i3/.config/i3/config` | `include ~/.config/i3/host.conf` (last line, after the `set`s) | **yes** (may be empty) |
| `x/.Xresources` | `#include ".Xresources.host"` — `Xft.dpi` lives only here | **yes** |
| `rofi/.config/rofi/config.rasi` | `@import "~/.config/rofi/host.rasi"` — rofi ignores `Xft.dpi`, so its `dpi` lives here | **yes** |
| `zsh/.zshrc` | `~/.zshrc.local` | no |
| `tmux/.tmux.conf` | `source-file -q ~/.tmux.local.conf` | no |
| `vim/.vimrc` | `~/.vimrc.local` | no |
| `git/.gitconfig` | `[include] path = ~/.gitconfig.local` | no |

Rules:
- The two required files exist in every host package even when empty, so
  nothing depends on how i3/xrdb treat a missing include.
- **Host files only add.** A setting that differs between hosts lives only
  in the host files, never in the shared file too (duplicate i3 `bindsym`s
  warn; a stale shared value is confusing).
- Host-only scripts go in `host-<name>/bin/`; Stow merges them with the
  shared `bin/` into `~/bin`.
- `system/<name>/` holds that host's boot entry, fstab and anything else
  with machine-specific values; `system/common/` everything else.
- Hardware notes, disk layout, quirks and service history: `hosts/<name>.md`.

Adding a host `foo`:
```sh
mkdir -p host-foo/.config/i3 system/foo
cp host-ultra/.Xresources.host host-foo/       # then set its DPI
touch host-foo/.config/i3/host.conf
cp hosts/ultra.md hosts/foo.md                 # then rewrite
./install.sh -n && ./install.sh
pkgs/update.sh
```

---

## 3. Base install

From the official Arch ISO, booted in **UEFI** mode
(`cat /sys/firmware/efi/fw_platform_size` → `64`; if the file is missing
you booted legacy — fix in BIOS).

### Network & clock
```sh
iwctl            # station wlan0 scan / get-networks / connect "SSID"
timedatectl      # "System clock synchronized: yes" (UTC in live env is fine)
```

### Disk
Partition layout, filesystems and any disk workarounds are per host — see
`hosts/<hostname>.md`. Mount root at `/mnt`, the ESP at `/mnt/boot`,
`/home` at `/mnt/home`.

### Base system
```sh
pacstrap -K /mnt base linux linux-firmware intel-ucode sudo vim networkmanager man-db
genfstab -U /mnt >> /mnt/etc/fstab
arch-chroot /mnt
```

### Inside the chroot
```sh
ln -sf /usr/share/zoneinfo/America/Chicago /etc/localtime
hwclock --systohc
sed -i 's/^#en_US.UTF-8/en_US.UTF-8/' /etc/locale.gen && locale-gen
echo LANG=en_US.UTF-8 > /etc/locale.conf
echo KEYMAP=us > /etc/vconsole.conf
echo <hostname> > /etc/hostname
passwd
useradd -m -G wheel <user> && passwd <user>
EDITOR=vim visudo           # uncomment: %wheel ALL=(ALL:ALL) ALL
systemctl enable NetworkManager NetworkManager-dispatcher fstrim.timer systemd-timesyncd
```

`/etc/mkinitcpio.conf` keeps the default **systemd-based** hooks (needed for
hibernation without kernel params; microcode is embedded via the
`microcode` hook):
```
HOOKS=(base systemd autodetect microcode modconf kms keyboard sd-vconsole block filesystems fsck)
```

### Bootloader — systemd-boot
```sh
bootctl install
```
`/boot/loader/loader.conf`
```
default arch.conf
timeout 3
```
`/boot/loader/entries/arch.conf`
```
title   Arch Linux
linux   /vmlinuz-linux
initrd  /initramfs-linux.img
options root=LABEL=root rw <host-specific params>
```
The real entry for each host is in `system/<host>/boot/`. Check: `blkid`
shows the root label/UUID; `bootctl list` shows the entry.

Emergency: at the boot menu press `e` to edit the options line (e.g. add
`noresume` if a hibernation resume ever hangs).

```sh
exit; umount -R /mnt; reboot
```

---

## 4. First boot

```sh
nmtui                     # Wi-Fi
sudo pacman -Syu
sudo pacman -S --needed base-devel git
git clone https://aur.archlinux.org/yay-bin.git && cd yay-bin && makepkg -si
cd .. && rm -rf yay-bin
```

Housekeeping:
```sh
sudo pacman -S pacman-contrib && sudo systemctl enable --now paccache.timer
```
(Keeps the 50 GB root from filling with old packages.)

Console font (readable at 1440p): `sudo pacman -S terminus-font`, then add
`FONT=ter-v24n` to `/etc/vconsole.conf`.

### Time sync & time zone
Arch ships `systemd-timesyncd` but doesn't enable it (missed on ultra at
first — the clock ran off the RTC, which the CMOS battery swap had reset):
```sh
sudo timedatectl set-ntp true      # enables + starts systemd-timesyncd
timedatectl                        # "System clock synchronized: yes", "RTC in local TZ: no"
sudo hwclock --systohc             # write the corrected time to the RTC (kept in UTC)
```
Default (Arch pool) servers are fine.

**Time zone follows the network** via `tzupdate` (AUR, IP geolocation) and a
NetworkManager dispatcher script,
`/etc/NetworkManager/dispatcher.d/90-tzupdate`:
```sh
#!/bin/sh
# Update the time zone from IP geolocation when a network connection comes up.
# $1 = interface, $2 = action. VPNs report "vpn-up", so they're ignored.
[ "$2" = "up" ] || exit 0
(
    sleep 5    # let DNS and routing settle first
    out=$(tzupdate 2>&1)
    logger -t tzupdate "$1: $out"
) &
```
- The script must be **owned by root and not group/world-writable**, or
  NetworkManager silently skips it — git doesn't keep ownership, so after
  restoring from `system/`:
  `sudo chown root:root …/90-tzupdate && sudo chmod 755 …/90-tzupdate`.
- Needs `NetworkManager-dispatcher` enabled (above).
- Log: `journalctl -t tzupdate`. Test by toggling Wi-Fi
  (`nmcli radio wifi off; nmcli radio wifi on`).
- **VPN caveat:** if the UIC VPN is already up when Wi-Fi reconnects, the
  lookup sees Chicago. Connect Wi-Fi first, then the VPN.
- Manual override: `sudo timedatectl set-timezone Europe/Lisbon`.
- Programs started before a change (Chrome, open shells) keep the old zone
  until restarted; the bar clock updates itself. gammastep needs nothing —
  it gets the location from geoclue.

---

## 5. Shell: zsh, tmux, SSH

### zsh + oh-my-zsh + powerlevel10k
```sh
sudo pacman -S zsh zsh-completions zsh-theme-powerlevel10k ttf-meslo-nerd
chsh -s /usr/bin/zsh
sh -c "$(curl -fsSL https://raw.githubusercontent.com/ohmyzsh/ohmyzsh/master/tools/install.sh)" "" --unattended --keep-zshrc
```
Notes on `.zshrc`:
- p10k comes from the **Arch package**, sourced directly
  (`source /usr/share/zsh-theme-powerlevel10k/powerlevel10k.zsh-theme`);
  `ZSH_THEME` stays commented out. Settings use the `POWERLEVEL9K_` prefix
  (p10k kept it).
- **No** `export TERM=…` — it breaks tmux's `tmux-256color` and the console.
- Console fallback: `[[ $TERM == linux ]] && POWERLEVEL9K_MODE=ascii`
  (before the p10k `source` line) — Nerd Font glyphs can't render on the VT.
- Guard VTE-only snippets:
  `[[ -f /etc/profile.d/vte.sh ]] && source /etc/profile.d/vte.sh`
- No `ssh-agent` plugin.
- `plugins=(...)` must come **before** `source $ZSH/oh-my-zsh.sh` — the old
  config had it after, so no plugins ever loaded.
- `bindkey -v` (vi mode). Inside tmux, Ctrl-h is taken by
  vim-tmux-navigator; Backspace still deletes.

**Auto-start tmux** in graphical terminals only — at the **top** of `.zshrc`:
```zsh
if [[ -z "$TMUX" && -o interactive && -n "$DISPLAY" ]]; then
  exec tmux new-session -A -s main
fi
```
The `$DISPLAY` check matters: a tmux session created from the text console
never gets `$DISPLAY`, which breaks the clipboard and anything graphical. If
that happens: `tmux kill-server`, open a new terminal.

### tmux (`~/.tmux.conf`)
Key settings (see file for all):
```tmux
set -gw mode-keys vi
set -s escape-time 10
set -g default-terminal "tmux-256color"
set -as terminal-features ",alacritty:RGB"
set -g focus-events on
set -g history-limit 50000
set -g base-index 1
setw -g pane-base-index 1
set -g renumber-windows on

# copy mode: v select, y yank to X clipboard
bind -T copy-mode-vi v send -X begin-selection
bind -T copy-mode-vi y send -X copy-pipe-and-cancel "xclip -selection clipboard"
# paste: p = tmux buffer, P = system clipboard
bind p paste-buffer
bind P run "xclip -o -selection clipboard | tmux load-buffer - && tmux paste-buffer"

bind r source-file ~/.tmux.conf \; display "reloaded"
```
Plus the **vim-tmux-navigator** block (Ctrl-h/j/k/l across vim splits and
tmux panes; `prefix C-l` clears the screen).

Copy/paste cheat sheet: `prefix [` → move → `v` → `y`; `prefix p` /
`prefix P` / `Ctrl+Shift+V`. Mouse selection is Alacritty's
(`Ctrl+Shift+C`).

### SSH
```sh
sudo pacman -S openssh
ssh-keygen -t ed25519 -C "$USER@$(hostname)"
ssh-copy-id user@host
```
`~/.ssh/config` — host aliases plus connection reuse (one passphrase per
session, no agent):
```
Host *
    ControlMaster auto
    ControlPath ~/.ssh/cm-%r@%h:%p
    ControlPersist 10m
```
Over SSH, paste into remote vim with `Ctrl+Shift+V` in insert mode (the
remote has no X clipboard).

### SSH server (into this laptop)
Order matters — authorize keys *before* turning passwords off:
```sh
sudo systemctl enable --now sshd
ssh-copy-id <user>@<laptop-ip>        # from each client machine; test login
```
`/etc/ssh/sshd_config.d/10-hardening.conf` (Arch's sshd_config includes
`sshd_config.d/*.conf`):
```
PasswordAuthentication no
KbdInteractiveAuthentication no
PermitRootLogin no
AllowUsers <user>
```
```sh
sudo sshd -t && sudo systemctl restart sshd   # validate first; keep a session open
```
Reach it as `<hostname>.local` via mDNS:
```sh
sudo pacman -S nss-mdns && sudo systemctl enable --now avahi-daemon
```
`/etc/nsswitch.conf`:
```
hosts: mymachines mdns_minimal [NOTFOUND=return] resolve [!UNAVAIL=return] files myhostname dns
```
A suspended laptop is unreachable; `HandleLidSwitchExternalPower=ignore`
would keep it awake on AC with the lid closed (not set). The fingerprint PAM
changes don't touch sshd.

---

## 6. Graphical session

### Packages
```sh
sudo pacman -S xorg-server xf86-input-libinput mesa intel-media-driver \
  xorg-xset xorg-xrandr xclip \
  i3-wm xss-lock alacritty rofi \
  ttf-dejavu noto-fonts noto-fonts-emoji ttf-liberation ttf-meslo-nerd \
  pipewire pipewire-pulse wireplumber pavucontrol \
  brightnessctl network-manager-applet playerctl \
  dunst libnotify blueman bluez bluez-utils udiskie \
  xdg-desktop-portal xdg-desktop-portal-gtk polkit-gnome \
  lightdm lightdm-gtk-greeter accountsservice
sudo systemctl enable bluetooth lightdm
```
Do **not** install `xf86-video-intel` — modesetting is better on Broadwell.

### HiDPI
`~/.Xresources` includes `~/.Xresources.host`, which comes from the host
package and sets the DPI (ultra: `Xft.dpi: 144`). LightDM's session script
merges it automatically (`xrdb` runs it through `cpp`, which handles the
`#include`). Check: `xrdb -query | grep dpi`. Qt apps (KeePassXC, VLC,
Insync) may need `export QT_SCALE_FACTOR=1.5` in `~/.xprofile`.

### Fonts
- `noto-fonts-emoji` — color emoji (without it Chrome shows nothing/boxes).
- `ttf-liberation` — metric-compatible Arial / Times New Roman / Courier New;
  fontconfig maps those names to it, so web pages lay out as designed
  instead of falling back to wider DejaVu.
- **GTK settings** (`gtk` package): Chrome draws its tab strip and menus with
  the GTK font, which a bare i3 setup never configures — tab titles came out
  cramped. `~/.config/gtk-{3,4}.0/settings.ini`:
  ```ini
  [Settings]
  gtk-font-name=Noto Sans 10
  gtk-xft-antialias=1
  gtk-xft-hinting=1
  gtk-xft-hintstyle=hintslight
  gtk-xft-rgba=rgb
  ```
  Restart Chrome fully (`pkill chrome`) after changing fonts. If a screen
  shows color fringes, use `gtk-xft-rgba=none`.
- No `fonts.conf` needed: fontconfig already defaults to slight hinting
  (`fc-match -v sans-serif | grep hintstyle` → `1`).

### LightDM
`/etc/lightdm/lightdm-gtk-greeter.conf` → under `[greeter]` (per host, in
`system/<host>/`; ultra:)
```
xft-dpi=144
```
(The greeter runs before `~/.Xresources` loads.) LightDM replaced the earlier
`startx`-on-tty1 setup; there's no startx line in `~/.zprofile` anymore and
`~/.xinitrc` is unused. Per-user startup commands go in `~/.xprofile`.

> If ever going back to `startx`: `~/.xinitrc` must source
> `/etc/X11/xinit/xinitrc.d/?*.sh` before `exec i3`, otherwise the systemd
> user session lacks `DISPLAY` and the GTK file-chooser portal fails
> ("cannot open display"), so upload buttons in Chrome do nothing.
> Quick live fix: `dbus-update-activation-environment --systemd DISPLAY XAUTHORITY`
> then `systemctl --user reset-failed xdg-desktop-portal-gtk && systemctl --user restart xdg-desktop-portal xdg-desktop-portal-gtk`.

### Touchpad — `/etc/X11/xorg.conf.d/30-touchpad.conf`
```
Section "InputClass"
    Identifier "touchpad"
    MatchIsTouchpad "on"
    Driver "libinput"
    Option "Tapping" "on"
EndSection
```

### Touchscreen — `/etc/X11/xorg.conf.d/40-touchscreen-off.conf`
Any touchscreen is ignored (factual's ELAN panel; no-op elsewhere):
```
Section "InputClass"
	Identifier "touchscreen-off"
	MatchIsTouchscreen "on"
	Option "Ignore" "on"
EndSection
```

### i3 (`~/.config/i3/config`)
Cleaned up from my previous machine's config:
- `$mod` = **Alt** (Mod1) — Left Win is free for the keyd nav layer.
- Vim focus/move: `$mod+h/j/k/l`, `$mod+Shift+h/j/k/l`; resize mode on
  `h/j/k/l`. Splits: `$mod+v` vertical, `$mod+Shift+v` horizontal.
- Launchers (rofi): `$mod+d` apps, `$mod+=` run, `$mod+Tab` windows,
  `$mod+c` calculator.
- Hardware keys bound directly (wpctl / brightnessctl); no xbindkeys.
- `$mod+Shift+x` → `~/bin/lock`.
- Bar: `status_command i3status-rs`, gruvbox colors; **no**
  `tray_output primary` (it hides the tray on a single screen).
- Autostart: dunst, nm-applet, blueman-applet, `udiskie -ANt`, polkit-gnome
  agent, xss-lock, KeePassXC, Insync.
- Removed: `xrandr --dpi` (DPI lives only in `.Xresources.host`).
- Last line includes `~/.config/i3/host.conf` (§2).

Reminder: `exec` lines only run at login; `Alt+Shift+r` doesn't rerun them.
After changing an autostart command, restart that process by hand or log
out/in.

### Alacritty (`~/.config/alacritty/alacritty.toml`)
```toml
[font]
normal = { family = "MesloLGS Nerd Font" }
size = 10
```

### rofi (`~/.config/rofi/config.rasi`)
```
configuration {
    modi: "drun,run,window,calc";
    show-icons: true;
    font: "DejaVu Sans Mono 11";
    matching: "fuzzy";
    drun-display-format: "{name}";
    kb-row-up: "Up,Control+k";
    kb-row-down: "Down,Control+j";
    kb-accept-entry: "Return,KP_Enter";
    kb-remove-to-eol: "";
}
@theme "gruvbox-dark"
```
(The last two `kb-` lines free Ctrl+j/k from their defaults.)
Calculator: `sudo pacman -S rofi-calc` (or AUR), bound to
`rofi -show calc -modi calc -no-show-match -no-sort -calc-command "echo -n '{result}' | xclip -selection clipboard"`
— Enter copies the result.

Optional extras: `rofi -show ssh -terminal alacritty`, `clipmenu`
(set `CM_IGNORE_WINDOW=KeePassXC`!), `rofi-emoji`, `~/bin/powermenu`.

### dunst
Gruvbox colors in `~/.config/dunst/dunstrc` (copied from `/etc/dunst/dunstrc`
and edited). `dunstctl close-all` = `$mod+Ctrl+Shift+Space`,
`dunstctl history-pop` to recall.

---

## 7. Keyboard

US layout on a UK keyboard.

### X11 options — Caps→Ctrl, Right Alt (AltGr)→Compose
```sh
sudo localectl --no-convert set-x11-keymap us "" "" ctrl:nocaps,compose:ralt
```
(Set both in **one** command — running it again with a single option
*replaces* the list.) Live: `setxkbmap -option -option ctrl:nocaps,compose:ralt`.
Compose examples: `RAlt ' a` → á, `RAlt , c` → ç, `RAlt ~ a` → ã.

### keyd — vim navigation layer everywhere (incl. console)
`/etc/keyd/default.conf`
```ini
[ids]
*

[main]
leftmeta = layer(nav)

[nav]
h = left
j = down
k = up
l = right
u = pageup
d = pagedown
```
```sh
sudo pacman -S keyd && sudo systemctl enable --now keyd
sudo keyd reload        # after edits; `sudo keyd monitor` to debug
```
Hold **Left Win** + `hjkl`/`u`/`d` → arrows / PgUp / PgDn.
(keyd is system-wide only; to version it, symlink this file from the repo.)

---

## 8. Bar: i3status-rust

```sh
sudo pacman -S i3status-rust lm_sensors fakeroot
```
Optional deps not needed: pulseaudio (pipewire-pulse covers it), alsa-utils,
powerline-fonts / font-awesome (Nerd Font has the glyphs), upower.

`~/.config/i3status-rust/config.toml` — theme `gruvbox-dark`, icons
`material-nf`. Blocks:

| Block | Notes |
|---|---|
| `disk_space` ×2 | `/` (warning 80 / alert 90 — percentages by default; **don't** set `alert_unit = "%"`) and `/home` |
| `net` | down/up speeds (`$ssid $signal_strength` optional) |
| `memory`, `cpu`, `temperature` (`coretemp-*`), `load` | cpu shows `$utilization $frequency` |
| `battery` | per-state formats ↓ ⚡ ✓ ⏸, `full_threshold = 99`, `$time_remaining` (`$time` is deprecated); left-click runs `~/bin/batmode` |
| `backlight` | scroll to change |
| `sound` ×2 | sink + `device_kind = "source"`; left-click → `toggle_mute` (default is right-click), right-click → pavucontrol |
| `notify` | `driver = "dunst"` |
| `toggle` "caffeine" | `xset s off -dpms` / `xset s on +dpms` |
| `weather` | `name = "nws"`, `units = "imperial"`, `autolocate = true`, `autolocate_interval = "once"` (met.no has no imperial option) |
| `time` | `%d/%b/%g %H:%M` |
| `packages` | `["pacman","aur"]`, `aur_command = "yay -Qua"`, hidden when up to date, warns on kernel updates, `signal = 1` |
| `privacy` | `v4l` (+ `pipewire`) — shows when camera/mic in use |
| `custom` SSD watchdog | `journalctl -k -b -q \| grep -c 'ata4.*failed'`, `hide_when_empty` |

Click rules: each `[[block.click]]` belongs to the `[[block]]` directly above
it. Test the config with `i3status-rs ~/.config/i3status-rust/config.toml`.

Pacman hook so the update count refreshes immediately —
`/etc/pacman.d/hooks/i3status-rust.hook`:
```ini
[Trigger]
Operation = Upgrade
Type = Package
Target = *

[Action]
When = PostTransaction
Exec = /usr/bin/pkill -SIGRTMIN+1 i3status-rs
```

---

## 9. Power: TLP, battery, hibernation

### TLP
```sh
sudo pacman -S tlp && sudo systemctl enable --now tlp
sudo tlp-stat -b
```
Which TLP plugin handles the battery is per host (ultra: `thinkpad` via
`natacpi` — see `hosts/ultra.md`).

**Charge thresholds** — `/etc/tlp.d/01-battery.conf` (in `system/<host>/`):
```
START_CHARGE_THRESH_BAT0=75
STOP_CHARGE_THRESH_BAT0=80
```
`sudo tlp start` to apply. `sudo tlp fullcharge` = one-off 100 %
(reverts at reboot); `sudo tlp setcharge` = back to 75/80.

**Bar toggle** (`~/bin/batmode` from the host package, left-click on the
battery block) needs —
`sudo visudo -f /etc/sudoers.d/tlp`:
```
<user> ALL=(root) NOPASSWD: /usr/bin/tlp fullcharge, /usr/bin/tlp setcharge
```

### Swap & hibernation
How swap is provided is per host; the host's fstab is in
`system/<host>/etc/fstab`. On ultra: an 8 GB swap file physically on the
`/home` partition, **exposed outside `/home` via a bind mount** —
`systemd-logind` runs with `ProtectHome=yes` and cannot see `/home/swapfile` ("Failed to get devno and offset for swap …").

```sh
sudo mkdir -m 700 /home/.swap /swap
sudo mkswap -U clear --size 8G --file /home/.swap/swapfile
sudo mount --bind /home/.swap /swap
sudo swapon /swap/swapfile
```
`/etc/fstab` (order matters):
```
/home/.swap     /swap  none  bind      0 0
/swap/swapfile  none   swap  defaults  0 0
```
No `resume=` params needed: with the systemd initramfs, systemd stores the
hibernation location in an EFI variable. Verify after boot: `swapon --show`.
Test: `systemctl hibernate` (you come back to the lock screen, not a hang).

### Suspend-then-hibernate
`/etc/systemd/logind.conf`:
```
HandleLidSwitch=suspend-then-hibernate
HandleLidSwitchExternalPower=suspend-then-hibernate
HandleSuspendKey=suspend-then-hibernate
```
Apply without logging out: `sudo systemctl kill -s HUP systemd-logind`
(**not** restart — that kills the session).
`HibernateDelaySec` left unset → battery-aware mode: wakes about hourly to
estimate drain, hibernates only when low. Using it on AC too covers
"suspended on AC, then unplugged". Measured suspend drain: ~0.5 %/h.

### Low battery while awake — `/etc/udev/rules.d/99-lowbat.rules`
```
SUBSYSTEM=="power_supply", ATTR{status}=="Discharging", ATTR{capacity}=="[0-5]", RUN+="/usr/bin/systemctl hibernate"
```

### Screen blanking
Temporarily: `xset s off -dpms` (bar caffeine toggle does this).

---

## 10. Lock screen

`yay -S i3lock-color` (replaces `i3lock`).

`~/bin/lock`:
- refuses to stack a second lock;
- locks KeePassXC via D-Bus
  (`org.keepassxc.KeePassXC.MainWindow.lockAllDatabases` — see open items);
- starts a background `fprintd-verify` loop that kills i3lock on a match
  (password **or** fingerprint unlocks);
- runs i3lock-color in the foreground: blurred screenshot, big clock,
  small ring; `--pass-volume-keys --pass-media-keys --pass-screen-keys` so
  mute/volume/brightness work while locked.

i3:
```
bindsym $mod+Shift+x exec --no-startup-id ~/bin/lock
exec --no-startup-id xss-lock --transfer-sleep-lock -- ~/bin/lock
```
After changing the script's invocation, restart xss-lock
(`pkill xss-lock; xss-lock --transfer-sleep-lock -- ~/bin/lock & disown`) —
`Alt+Shift+r` doesn't rerun `exec` lines.

Tried and dropped: `loginctl lock-session` binding (no session ID visible to
the binding; not worth the debugging).

---

## 11. Fingerprint

```sh
lsusb                          # find the reader (per host: hosts/<host>.md)
sudo pacman -S fprintd
sudo fprintd-enroll "$USER"    # ~5 swipes/touches; plain fprintd-enroll needs a polkit agent
fprintd-verify
```
If the reader reports "Device … is already open":
`sudo systemctl restart fprintd`.

**Concurrent password-or-fingerprint** with
`yay -S pam-fprint-grosshack`. In `/etc/pam.d/sudo` (top of the auth
section) and `/etc/pam.d/polkit-1` (copy from `/usr/lib/pam.d/polkit-1`
first):
```
auth  sufficient  pam_fprintd_grosshack.so
auth  sufficient  pam_unix.so try_first_pass
```
(Keep a root shell open while editing PAM files.) Not used for i3lock — it
collects the password itself; the lock script handles the fingerprint.

Polkit agent (also needed for KeePassXC quick unlock, udiskie, etc.):
```
exec --no-startup-id /usr/lib/polkit-gnome/polkit-gnome-authentication-agent-1
```

Face unlock (Howdy) deliberately **not** used: no IR camera, so a photo can
fool it.

---

## 12. Applications

### Vim (`~/.vimrc`)
vim-plug self-installs on first launch. Plugins: vim-latex, ALE (with
clangd), vim-tmux-navigator, gruvbox, fzf.vim, commentary, surround,
fugitive.
```sh
sudo pacman -S fzf ripgrep clang bear texlive-binextra   # chktex for ALE
```
Highlights: `set number` (absolute), persistent undo in `~/.vim/undo`,
smartcase search (`Esc Esc` clears), `clipboard=unnamedplus`, `autochdir`,
spell for tex/markdown/gitcommit. Keys: `Ctrl-p` files, `\g` ripgrep,
`\b` buffers, `Ctrl-]` / `Ctrl-T` go-to-definition and back (ALE updates
the tag stack), `gr` references, `K` hover. `bear -- make` for
`compile_commands.json`.

Prose (`tex`, `text`): `textwidth=0 wrap linebreak breakindent spell`, and
`j`/`k` move by screen line (by real line with a count) — soft-wrapped
paragraphs instead of hard line breaks. Markdown and commit messages: spell
only.

Arch's `vim` already has `+clipboard`; no need for `gvim`.

### Chrome
`yay -S google-chrome`. Flags go in `~/.config/chrome-flags.conf` (one per
line). HiDPI comes from `Xft.dpi`; if it ever isn't honored:
`--force-device-scale-factor=1.5`. Upload dialogs need the portal (§6).

### KeePassXC
```sh
sudo pacman -S keepassxc
```
- Autostart minimized to tray; "Minimize instead of app exit".
- Browser integration → Chrome + KeePassXC-Browser extension.
- Lock on inactivity; auto-reload database when changed externally.
- **Quick Unlock via polkit** (KeePassXC ≥ 2.8.0): needs the polkit agent
  and the grosshack lines in `/etc/pam.d/polkit-1`; not remembered across
  KeePassXC restarts on Linux.
- Database is synced via cloud storage; resolve conflict copies with
  Database → Merge.

### Insync (Google Drive)
`yay -S insync`; autostart `insync start`. Use **selective sync** (home is
~187 GB). `insync-thunar` when Thunar is installed.

### Camera
```sh
sudo pacman -S v4l-utils vlc vlc-plugins-all
v4l2-ctl --list-devices
vlc v4l2:///dev/video0
```
Assumes a UVC webcam. Per-host camera notes (BIOS toggles, drivers) are
in `hosts/<host>.md`.

### Spotify
`sudo pacman -S spotify-launcher`;
`~/.config/spotify-launcher.conf`:
```
[spotify]
extra_arguments = ["--force-device-scale-factor=1.5"]
```
(The 1.5 matches ultra's 144 DPI; not stowed yet, so set it per host.)
(Terminal alternative with Premium: `ncspot`.) Media control via
`playerctl`; i3status-rust `music` block. Spotify sets its window class
late, so plain i3 `for_window [class="Spotify"]` rules may not apply.

### htop
Configured via F2: tree view, hide kernel/userland threads, highlight
basename, CPU frequency + temperature, 2 s delay; meters: CPUs, Memory, Swap
| Tasks, Load, Uptime, Battery, Disk IO, Network IO.

### Night light — gammastep + geoclue
```sh
sudo pacman -S gammastep geoclue
```
`~/.config/gammastep/config.ini` (stowed): 6500 K day / 3700 K night,
`location-provider=geoclue2`, `adjustment-method=randr`, `fade=1`. The
transition follows solar elevation (+3° → −6°, ~45–60 min around sunset).

geoclue gotchas (all hit on this machine):
- After installing geoclue, **reload D-Bus or reboot** — its D-Bus policy is
  loaded before the `geoclue` user exists, and requests silently time out.
- No Wi-Fi geolocation URL is set by default (Mozilla's service is gone).
  `/etc/geoclue/conf.d/99-beacondb.conf`:
  `[wifi]` / `url=https://api.beacondb.net/v1/geolocate`. beaconDB has no
  Wi-Fi coverage here yet, so it falls back to GeoIP (~25 km) — fine for
  sunsets.
- gammastep is listed as an app in
  `/etc/geoclue/conf.d/90-gammastep.conf`:
  `[gammastep]` / `allowed=true` / `system=false` / `users=`.
  `/etc/geoclue/geoclue.conf` stays stock (only drop-ins are kept here), so
  package updates don't leave a `.pacnew`.
- A geoclue **agent must be running** to authorize clients; i3 starts
  `/usr/lib/geoclue-2.0/demos/agent` before gammastep.
- Test: `/usr/lib/geoclue-2.0/demos/where-am-i -t 30`, then `gammastep -v -p`.

Bar: an i3status-rust `toggle` block (moon/sun icon) starts/stops gammastep.
`command_on` must redirect output (`setsid -f gammastep >/dev/null 2>&1`),
or the block waits on the inherited pipe and freezes until i3 restarts.

---

## 13. System files checklist

Kept as copies under `system/` (restore by hand). `common/` applies to every
host; `<host>/` holds files with machine-specific values.

| File | Where | Purpose |
|---|---|---|
| `/boot/loader/loader.conf`, `/boot/loader/entries/arch.conf` | `ultra/` | systemd-boot; root and kernel params |
| `/etc/fstab` | `ultra/` | partitions; hibernation swap |
| `/etc/lightdm/lightdm-gtk-greeter.conf` | `<host>/` | greeter DPI |
| `/etc/tlp.d/01-battery.conf` | `ultra/` | charge thresholds |
| `/etc/mkinitcpio.conf` | `common/` | systemd hooks (default) |
| `/etc/vconsole.conf` | `common/` | `KEYMAP=us` |
| `/etc/X11/xorg.conf.d/00-keyboard.conf` | `common/` | `ctrl:nocaps,compose:ralt` (written by localectl) |
| `/etc/X11/xorg.conf.d/30-touchpad.conf` | `common/` | tap-to-click |
| `/etc/X11/xorg.conf.d/40-touchscreen-off.conf` | `common/` | ignore any touchscreen |
| `/etc/keyd/default.conf` | `common/` | nav layer |
| `/etc/systemd/logind.conf` | `common/` | suspend-then-hibernate |
| `/etc/pam.d/sudo`, `/etc/pam.d/polkit-1` | `common/` | fingerprint (grosshack) |
| `/etc/ssh/sshd_config.d/10-hardening.conf` | `common/` | key-only SSH |
| `/etc/geoclue/conf.d/99-beacondb.conf`, `/etc/geoclue/conf.d/90-gammastep.conf` | `common/` | location for gammastep (drop-ins; `geoclue.conf` stays stock) |
| `/etc/nsswitch.conf` | `common/` | mDNS (`<hostname>.local`) |
| `/etc/NetworkManager/dispatcher.d/90-tzupdate` | `common/` | time zone from IP on connect (restore as root:root, 755) |

Services enabled: `NetworkManager`, `fstrim.timer`, `paccache.timer`, `tlp`,
`bluetooth`, `keyd`, `lightdm`, `sshd`, `avahi-daemon`, `systemd-timesyncd`,
`NetworkManager-dispatcher`.

Not in `system/` yet (not created on ultra, or not copied):
`/etc/sudoers.d/tlp`, `/etc/udev/rules.d/99-lowbat.rules`,
`/etc/pacman.d/hooks/i3status-rust.hook` — their contents are in §8–9.
Usernames in copied files are replaced with `<user>`.

---

## 14. Open items & known issues

- **Hostname not shown in the p10k prompt** — `DEFAULT_USER` removed and
  `POWERLEVEL9K_ALWAYS_SHOW_CONTEXT` tried; probably a `~/.p10k.zsh`
  setting (`POWERLEVEL9K_CONTEXT_{DEFAULT,SUDO}_…_EXPANSION=`). Unresolved.
- **KeePassXC lock from the lock script** — the D-Bus call was not confirmed
  working; `keepassxc --lock` works but pops up the window. Fallback:
  KeePassXC locks on suspend/lid and on inactivity.
- **Fingerprint reader** (ultra) occasionally gets stuck ("already open") →
  `sudo systemctl restart fprintd`.
- **Mic-mute key (F4)** may not pass through the lock screen.
- **Screen tearing** (if noticed in Chrome): `Option "TearFree" "true"` for
  the modesetting driver.
- **Later:** Thunar (+ gvfs, tumbler, insync-thunar);
  `xdg-desktop-portal-termfilechooser` with a terminal file manager as the
  file dialog; OSC 52 clipboard over SSH (`set -g set-clipboard on` +
  vim-oscyank on remotes).
