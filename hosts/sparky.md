# sparky — Dell XPS 15 7590 (2019)

Host-specific notes for `sparky`. Shared setup is in the [README](../README.md).

| | |
|---|---|
| Hostname | `sparky` |
| Host package | `host-sparky/` — `.Xresources.host` (220 DPI), `.config/rofi/host.rasi`, `.config/i3/host.conf` (starts `desk-watch.sh`), `bin/desk.sh`, `bin/desk-watch.sh` |
| System files | `system/sparky/` — NVIDIA off (modprobe block, udev runtime-PM rule, TLP deny list) |
| Packages | `pkgs/sparky*.txt` (extras beyond `pkgs/common*.txt`) |

Lives docked (Dell WD19TB) with two external screens, lid open.

## Hardware

| Item | Detail |
|---|---|
| CPU / GPU | i7-9750H; Intel UHD 630 drives everything; NVIDIA GTX 1650 Mobile (TU117) kept **off** — see below |
| Display | 3840×2160 on 15.6" → 220 DPI, unscaled |
| RAM | 2 × 32 GB Kingston `KF3200C20S4/32GX` (matched), at 2933 MT/s |
| Storage | Toshiba XG6 NVMe: ESP on `/efi`, ext4 `/`, ext4 `/home`, 23 GB swap partition |
| Boot | GRUB; firmware 1.2.3 (2019) |
| Network | Ethernet through the dock (`r8152`); Wi-Fi Killer AX1650x (`iwlwifi`) |
| Fingerprint | Goodix `27c6:5395` — **not supported by libfprint**; the shared PAM files skip the fingerprint modules when they're missing |
| Battery | `DELL GPM0365`, ~78 % of design (Nov 2026); TLP `dell` plugin, 75/80 thresholds, `charge_types` = Custom |
| Keyboards | External Apple aluminium + Keychron K2 (Mac layout): **Cmd** is Left Win for keyd |

## Service history / known faults
- **Powers off when picked up or moved**; fine when still. Suspected cracked
  solder joint (or the USB-C/dock port). Watch the battery for swelling
  (bulging bottom, raised touchpad).
- One DIMM failed years ago; replaced like-for-like (both sticks match).
- 2026-11-12: several hard power-offs while sorting out the NVIDIA card.
  `.zsh_history` and `/var/log/pacman.log` got NUL bytes; worth a
  `pacman -Qk 2>/dev/null | grep -v ' 0 missing'` sometime.

## Displays — `desk.sh`

| Role | Screen (EDID) | Output today | Scale | Position | Workspaces |
|---|---|---|---|---|---|
| portrait | Acer `K242HQL`, 1080p, rotated right | `DP-1-3` | 2 | 0×0 | 1 2 3 |
| monitor | Dell `U2718Q`, 4K, **primary** | `DP-1-1` | 1.25 | 2160×1680 | 4–7 |
| laptop | panel `156WR04` | `eDP-1` | 1 | 6960×1680 | 8 9 10 |

Layouts: `desk`, `closed` (lid shut: 4–10 on the monitor), `laptop`.
Screens are matched by EDID model, so ports don't matter. X uses
`modesetting` (`xf86-video-intel` removed), hence the dashed output names.

## NVIDIA GPU: off, no driver

Why (all on 2026-11-12, `nvidia-open` 610, kernel 7.1):
- No screen needs it: every output is wired to the Intel GPU.
- The driver couldn't start the card anyway:
  `_kgspBootGspRm: unexpected WPR2 already up`.
- **bbswitch froze the machine** three ways: switching the card on
  (`echo ON > /proc/acpi/bbswitch`), loading the driver onto a
  bbswitch-off card (`nvidia-smi`), and X shutting down (logout) with the
  card bbswitch-off. bumblebee + bbswitch removed.
- NVIDIA's own runtime D3 (`NVreg_DynamicPowerManagement=0x02`) only
  reached D3hot, with the PCIe port still active.

Now:
- `/etc/modprobe.d/nvidia-off.conf` — `install nvidia… /bin/false`: the
  driver can't load; `modprobe nvidia` errors out instead of hanging.
- `/etc/udev/rules.d/80-nvidia-off.rules` — `power/control=auto` on the
  card and its root port `00:01.0`; the port suspends and cuts the slot's
  power → card in **D3cold**.
- `/etc/tlp.d/10-sparky-nvidia.conf` — `RUNTIME_PM_DENYLIST`, because
  TLP's `RUNTIME_PM_ON_AC=on` would otherwise undo the rule at boot.

Effect: ~27–28 W → ~15–16 W at idle, docked with three screens.
Check: `cat /sys/bus/pci/devices/0000:01:00.0/power_state` → `D3cold`.
Measure (RAPL psys, 10 s average):
```sh
d=$(dirname $(grep -l psys /sys/class/powercap/intel-rapl*/name))
a=$(sudo cat $d/energy_uj); sleep 10; b=$(sudo cat $d/energy_uj); echo $(( (b - a) / 10000000 )) W
```

**CUDA (untested):** comment out the `install` lines, then
`sudo modprobe nvidia` (the kernel powers the card up before the driver
binds) and `nvidia-smi`. Never use bbswitch. If the driver reports the WPR2
error, a cold boot clears it.

## Packages and upgrades
- Pinned to the Arch Linux Archive for **2026-08-20** (Sparky's last full
  upgrade) in `/etc/pacman.d/mirrorlist`; the normal list is saved as
  `mirrorlist.normal`. This let the shared packages install mid-semester
  without a partial upgrade. At the break: restore the mirrorlist,
  `pacman -Syu`, and watch the DKMS modules (`nvidia-open-dkms`,
  `vmware-*-dkms`).
- The dead `[community]` repo is commented out in `pacman.conf`.

## Account
User renamed `lganchin` → `luispina` (UID 1000) on 2026-11-12.
`/home/lganchin` is a symlink to `/home/luispina`, so old absolute paths
(Docker `data-root`, Insync, conda, VMs, …) keep working.

## Open items
- **Weather in °C** on i3status-rust 0.36.1 despite `units = "imperial"`
  under `[block.service]`. Recheck after the full upgrade; newer versions
  take `units` at block level.
- **`sparky` doesn't resolve** from other machines (`ultra`/`factual` do).
- Rename leftovers: 16 travel Wi-Fi connections restricted to
  `user:lganchin`; Docker `data-root` still under `/home/lganchin`.
- Remove the `video=1366x768` kernel parameter (floods dmesg with i915
  warnings).
- Remaining system files: nsswitch, PAM, vconsole, logind (no hibernation
  here: 23 GB swap vs 64 GB RAM), mkinitcpio, greeter DPI.
- Old packages to remove: `lightdm-webkit2-greeter`, `bumblebee-status`,
  `betterlockscreen`; merge `lightdm.conf.pacnew`.
- Firmware 1.2.3 is old; update at a break.
- RVM / Jekyll (together with factual).
- `~/repos/dotfiles-old` holds the previous setup, mutt included.
