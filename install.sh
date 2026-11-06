#!/bin/sh
# Link dotfiles packages into $HOME (target set by .stowrc).
#
#   ./install.sh                 shared packages + host-<hostname>
#   ./install.sh zsh tmux        only these packages
#   ./install.sh host            only this machine's host-<hostname>
#   ./install.sh -l              list packages and whether they're linked
#   ./install.sh -n [pkg…]       dry run
#   ./install.sh -D [pkg…]       unlink
#   ./install.sh -R [pkg…]       relink (after adding/removing files)
#   HOST=ultra ./install.sh …    override the host name
set -eu
cd "$(dirname "$0")"

host=${HOST:-$(uname -n)}
hostpkg="host-$host"

usage() { sed -n '3,11p' "$0" | sed 's/^# \{0,1\}//' >&2; exit 2; }

mode=-S list=0
while getopts nDRlh opt; do
    case $opt in
        n) mode=-n ;;
        D) mode=-D ;;
        R) mode=-R ;;
        l) list=1 ;;
        *) usage ;;
    esac
done
shift $((OPTIND - 1))

shared=""
for p in */; do
    p=${p%/}
    case "$p" in system|pkgs|hosts|host-*) continue ;; esac
    shared="$shared $p"
done
have_host=0; [ -d "$hostpkg" ] && have_host=1

# state of one package: linked / partial / not linked / conflict
state() {
    out=$(stow -n -v "$1" 2>&1) || { echo "conflict"; return; }
    if ! printf '%s\n' "$out" | grep -q '^LINK\|^MKDIR'; then echo "linked"
    elif stow -n -v -D "$1" 2>&1 | grep -q '^UNLINK'; then echo "partial"
    else echo "not linked"; fi
}

if [ "$list" = 1 ]; then
    for p in $shared $( [ "$have_host" = 1 ] && echo "$hostpkg" ); do
        printf '  %-14s %s\n' "$p" "$(state "$p")"
    done
    [ "$have_host" = 1 ] || echo "  ($hostpkg does not exist yet)"
    exit 0
fi

# which packages
full=0
if [ $# -eq 0 ]; then
    full=1
    if [ "$have_host" = 0 ] && [ "$mode" != -D ]; then
        echo "No $hostpkg package. Create it (at least .Xresources.host and" >&2
        echo ".config/i3/host.conf, see README §2), set HOST=<name>, or name" >&2
        echo "packages to install them one at a time." >&2
        exit 1
    fi
    # shellcheck disable=SC2086
    set -- $shared
    [ "$have_host" = 1 ] && set -- "$@" "$hostpkg"
fi

pkgs=""
for p in "$@"; do
    p=${p%/}
    [ "$p" = host ] && p=$hostpkg
    case " $shared $hostpkg " in
        *" $p "*) [ -d "$p" ] || { echo "$p does not exist yet" >&2; exit 1; } ;;
        *) echo "unknown package: $p" >&2; echo "packages:$shared $hostpkg" >&2; exit 1 ;;
    esac
    pkgs="$pkgs $p"
done

# x and i3 include files from the host package
if [ "$mode" != -D ]; then
    case " $pkgs " in *" $hostpkg "*) ;; *)
        for p in x i3; do
            case " $pkgs " in *" $p "*)
                if [ "$have_host" = 0 ] || [ "$(state "$hostpkg")" != linked ]; then
                    echo "note: $p includes files from $hostpkg; link it too (./install.sh host)" >&2
                fi ;;
            esac
        done ;;
    esac
fi

# shellcheck disable=SC2086
case $mode in
    -n) stow -n -v $pkgs ;;
    *)  stow $mode -v $pkgs ;;
esac

[ "$full" = 1 ] && [ "$mode" = -S ] || exit 0
cat <<MSG

Linked:$pkgs

System files are copied by hand (README §13):
  system/common/   all hosts
  system/$host/   this host only
Packages:
  sudo pacman -S --needed - < pkgs/common.txt
  sudo pacman -S --needed - < pkgs/$host.txt
  yay -S --needed - < pkgs/common-aur.txt
  yay -S --needed - < pkgs/$host-aur.txt
MSG
