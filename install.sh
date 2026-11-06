#!/bin/sh
# Link the shared packages plus host-<hostname> into $HOME (via .stowrc).
#   ./install.sh            link for this machine
#   ./install.sh -n         dry run (show what would happen)
#   ./install.sh -D         unlink everything (before moving files around)
#   HOST=ultra ./install.sh override the host name
set -eu
cd "$(dirname "$0")"

host=${HOST:-$(uname -n)}
mode=-v
case "${1:-}" in
    -n) mode="-nv" ;;
    -D) mode="-Dv" ;;
    "") ;;
    *)  echo "usage: $0 [-n|-D]" >&2; exit 2 ;;
esac

if [ ! -d "host-$host" ]; then
    echo "No host-$host package. Create it (at least .Xresources.host and" >&2
    echo ".config/i3/host.conf, see README §2) or set HOST=<name>." >&2
    exit 1
fi

pkgs=""
for p in */; do
    p=${p%/}
    case "$p" in
        system|pkgs|hosts|host-*) continue ;;
    esac
    pkgs="$pkgs $p"
done

# shellcheck disable=SC2086
stow $mode $pkgs "host-$host"

[ "$mode" = "-v" ] || exit 0
cat <<MSG

Linked:$pkgs host-$host

System files are copied by hand (README §13):
  system/common/   all hosts
  system/$host/   this host only
Packages:
  sudo pacman -S --needed - < pkgs/common.txt
  sudo pacman -S --needed - < pkgs/$host.txt
  yay -S --needed - < pkgs/common-aur.txt
  yay -S --needed - < pkgs/$host-aur.txt
MSG
