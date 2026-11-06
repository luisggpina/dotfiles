#!/bin/sh
# Refresh this host's package lists: everything explicitly installed that is
# not already in the common lists. To share a package between hosts, move its
# line into common*.txt by hand and rerun.
set -eu
cd "$(dirname "$0")"
host=${HOST:-$(uname -n)}

tmp=$(mktemp -d); trap 'rm -rf "$tmp"' EXIT
sort -u common.txt     > "$tmp/c"
sort -u common-aur.txt > "$tmp/ca"
pacman -Qqen | sort | comm -23 - "$tmp/c"  > "$host.txt"
pacman -Qqem | sort | comm -23 - "$tmp/ca" > "$host-aur.txt"

# Common packages this host no longer has (removed here, or never installed)
missing=$(pacman -Qqe | sort | comm -13 - "$tmp/c")
missing_aur=$(pacman -Qqe | sort | comm -13 - "$tmp/ca")
[ -z "$missing$missing_aur" ] || {
    echo "In common lists but not installed here:"
    printf '  %s\n' $missing $missing_aur
}
echo "Wrote pkgs/$host.txt ($(wc -l < "$host.txt")) and pkgs/$host-aur.txt ($(wc -l < "$host-aur.txt"))"
