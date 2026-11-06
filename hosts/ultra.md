# ultra — ThinkPad X1 Carbon Gen 3 (2015)

Host-specific notes for `ultra`. Shared setup is in the [README](../README.md).

| | |
|---|---|
| Hostname | `ultra` |
| Host package | `host-ultra/` — `.Xresources.host` (144 DPI), `.config/i3/host.conf` (empty), `bin/batmode` |
| System files | `system/ultra/` — systemd-boot entry, fstab, greeter DPI, TLP thresholds |
| Packages | `pkgs/ultra*.txt` (extras beyond `pkgs/common*.txt`) |

## Hardware

| Item | Detail |
|---|---|
| Display | 2560×1440 (WQHD) → everything scaled to 144 DPI |
| Keyboard | UK physical layout, **used as US** |
| SSD | Samsung M.2 **SATA** (~256 GB), `/dev/sda`, on `ata4` / `host3` |
| Wi-Fi | Intel 7265 (`iwlwifi`), no built-in Ethernet |
| Camera | Standard UVC webcam, `/dev/video0` (no IR) |
| Fingerprint | Validity VFS5011 swipe sensor, USB `138a:0017` (libfprint `vfs5011`) |
| Battery | Replacement `45N1702`; reports 58.6 Wh vs 48.8 Wh design (~120 %) |

## Service history
- Replaced **CMOS battery** and **main battery** (Nov 2026). CMOS swap
  resets BIOS settings — re-check boot mode after any future swap.
- **Broken ZIF connector latch** on the *mainboard* side of the ribbon to
  the USB/Ethernet sub-board. Held with electrical tape; everything works.
  - Next time the bottom cover is off: replace electrical tape with
    **Kapton** (heat-resistant), optionally a foam shim for pressure.
  - Symptom if it fails: that USB port / Ethernet dongle drops out
    (`sudo dmesg -w | grep -i usb`).
  - Real fix: micro-soldering a new connector (board repair shop).

## SSD write timeouts (important)
During install the SSD threw `ata4.00: failed command: WRITE FPDMA QUEUED …
Emask 0x4 (timeout)` under heavy writes. SMART is healthy (no reallocated
sectors, no uncorrectable/CRC errors, ~16 % wear, PASSED), so the cause is a
firmware/link quirk, not failing flash. Mitigations, now permanent:

- Kernel params: `libata.force=noncq ahci.mobile_lpm_policy=1`
  (NCQ off, SATA link power management at max performance)
- Format ext4 with `-E nodiscard`; never use the `discard` mount option —
  rely on weekly `fstrim.timer` instead.
- The bar has a watchdog block that appears only if `ata4 … failed` shows up
  in the kernel log.

Health check any time: `sudo smartctl -H -A /dev/sda`

## BIOS (F1 at boot)
- Startup → UEFI/Legacy Boot: **UEFI Only** (the old install was legacy/MBR)
- Security → Secure Boot: **Disabled**
- F12 = boot menu

## Install specifics

These replace the "Disk" step of README §3.

### SSD workarounds for the live session
Apply **before** writing to the disk:
```sh
echo max_performance > /sys/class/scsi_host/host3/link_power_management_policy
echo 1   > /sys/block/sda/device/queue_depth      # NCQ off
echo 512 > /sys/block/sda/queue/max_sectors_kb   # smaller requests
```
(Other `host*` entries refuse LPM changes — harmless.)

### Partitioning — GPT
| Part | Size | Type | FS | Mount |
|---|---|---|---|---|
| `sda1` | 1 GiB | EF00 | FAT32 `EFI` | `/boot` |
| `sda2` | 50 GiB | 8300 | ext4 `root` | `/` |
| `sda3` | rest (~187 GiB) | 8300 | ext4 `home` | `/home` |

```sh
sgdisk -o \
  -n 1:0:+1G  -t 1:ef00 -c 1:EFI  \
  -n 2:0:+50G -t 2:8300 -c 2:root \
  -n 3:0:0    -t 3:8300 -c 3:home \
  /dev/sda
```
(Mind the colons: `1:0:+1G`, not `1:0+1G`.)

```sh
mkfs.fat -F 32 -n EFI /dev/sda1
mkfs.ext4 -E nodiscard -L root /dev/sda2
mkfs.ext4 -E nodiscard -L home /dev/sda3
e2fsck -fn /dev/sda2; e2fsck -fn /dev/sda3   # verify after any ata4 timeouts

mount /dev/sda2 /mnt
mount --mkdir /dev/sda1 /mnt/boot
mount --mkdir /dev/sda3 /mnt/home
```

Boot entry (`system/ultra/boot/loader/entries/arch.conf`) carries the SSD
parameters from above:
```
options root=LABEL=root rw libata.force=noncq ahci.mobile_lpm_policy=1
```

## Power

TLP uses the `thinkpad` plugin via `natacpi` (thresholds + force-discharge),
which is what `~/bin/batmode` (`tlp fullcharge` / `tlp setcharge`) relies on.

**Calibration** (new battery, or when estimates drift): on AC,
`sudo tlp recalibrate BAT0` — charges, force-discharges to empty, recharges.
Runs in the foreground for hours; don't log out / kill tmux. If interrupted,
the battery can be left in force-discharge (running on battery while
plugged in). Check / reset:
```sh
cat /sys/class/power_supply/BAT0/charge_behaviour      # want [auto]
echo auto | sudo tee /sys/class/power_supply/BAT0/charge_behaviour
```
Routine: every month or two, charge to 100 % and run it down to ~10–15 % so
the fuel gauge stays accurate (auto-hibernate depends on it).

Swap: 8 GB swap file on `/home`, exposed through a bind mount — details in
README §9; the lines are in `system/ultra/etc/fstab`.

## Fingerprint

Validity VFS5011 **swipe** sensor, `lsusb` → `138a:0017 Validity Sensors`
(libfprint `vfs5011`). Enrollment takes ~5 swipes.

## Camera

Standard UVC webcam at `/dev/video0` (no IR, hence no Howdy). If it's
missing: BIOS → Security → I/O Port Access → Integrated Camera.

## Open items

- **Battery capacity** reports ~120 % of design — verify with a real
  unplugged day; recalibrate if the gauge seems optimistic.
