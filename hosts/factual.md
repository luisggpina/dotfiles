# factual — Dell XPS 13 9340 (2024)

Host-specific notes for `factual`. Shared setup is in the [README](../README.md).

| | |
|---|---|
| Hostname | `factual` |
| Host package | `host-factual/` — `.Xresources.host` (200 DPI), `.config/rofi/host.rasi`, `.config/i3/host.conf` (starts `desk-watch.sh`), `bin/desk.sh`, `bin/desk-watch.sh` |
| System files | `system/factual/` — systemd-boot entry, fstab (swap file for hibernation), greeter DPI |
| Packages | `pkgs/factual*.txt` (extras beyond `pkgs/common*.txt`) |

Took over sparky's role a few years ago (its setup started as a copy of
sparky's). Docked at the desk, often with a TV as a third screen.

## Hardware

| Item | Detail |
|---|---|
| CPU / GPU | Core Ultra 7 155H (Meteor Lake); Intel Arc graphics, `i915` (`xe` also available) |
| Display | 2880×1800 on 13.4" → 200 DPI. ELAN touchscreen ignored (`40-touchscreen-off.conf`) |
| RAM | 64 GB LPDDR5 on board, 7467 MT/s |
| Storage | Samsung PM9F1 1 TB NVMe: `p1` 1 GiB ESP on `/boot`, `p2` 50 GiB ext4 `/`, `p3` ~903 GiB ext4 `/home`; 64 GB swap file on `/home` |
| Boot | systemd-boot; firmware 1.6.0 (2024-05-09); Secure Boot off |
| Network | Wi-Fi 7 Intel BE200 (`iwlwifi`), Bluetooth on the same card; no built-in Ethernet — 2.5 GbE (Realtek RTL8156) through the dock |
| Fingerprint | Goodix `27c6:633c` (libfprint `goodixmoc`); shared PAM files (LightDM, sudo, polkit) |
| Battery | `DELL J7H5M47F`, 88 % of design (4123 / 4687 mAh, Nov 2026); TLP `dell` plugin, 75/80 thresholds, `charge_types` = Custom |
| Camera | Built-in: MIPI sensor behind the Intel IPU6 (`intel-ipu6`), not a plain UVC webcam — see Camera below |
| At the desk | Keychron K3 keyboard (shows up in `lsusb` as an Apple aluminium keyboard, `05ac:024f`), Keychron M3 mouse, Logitech C920 PRO and AnkerWork C310 webcams (UVC) |

## Displays — `desk.sh`

Screens are matched by output name and resolution (no EDID strings yet).

| Role | Matched by | Scale | Workspaces (`office` / `desk`) |
|---|---|---|---|
| laptop | `eDP…` | 1.25 | 1 2 3 / 1 2 3 |
| monitor | `DP-n-n` (through the dock), 4K, **primary** | 1.25 | 4 5 6 / 4 5 6 8 9 10 |
| tv | `DP-n` (direct), 4096×2160, run at 3840×2160 | 1 | 8 9 10 / — |

Layouts: `office` (all three), `desk` (docked, no TV), `laptop`.

## Power

Swap: 64 GB swap file at `/home/.swap/swapfile`, exposed as `/swap` through
a bind mount (README §9); the lines are in `system/factual/etc/fstab`.
Suspend-then-hibernate as in the shared `logind.conf`.

## Camera

The built-in camera goes through the IPU6, which shows up as dozens of raw
`/dev/video*` nodes; apps need libcamera/PipeWire to get a picture from it.
Chrome works; the Zoom desktop client doesn't see it. The USB webcams at
the desk are plain UVC.

## Packages and upgrades
- Full upgrades with `yay -Syu`, repos first and AUR later; not in the
  middle of the semester.
- reflector set up here first (Nov 2026); run by hand before upgrades, no
  timer.

## Open items
- Zoom desktop client can't see the built-in camera (Chrome can) — waiting
  for Zoom to support it.
- RVM / Jekyll (together with sparky).
