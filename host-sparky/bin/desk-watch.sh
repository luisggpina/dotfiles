#!/bin/bash
#
# desk-watch.sh -- run desk.sh whenever X notices a display appear or vanish.
#
# Start it from your i3 config:
#     exec --no-startup-id ~/bin/desk-watch.sh
#
# It listens for RandR events on the root window, collapses the burst a dock
# generates into one trigger, waits for things to settle, then runs desk.sh.
# No root, no udev, no XAUTHORITY guessing: it inherits the session it lives in.
#
set -u

DESK=${DESK:-$HOME/bin/desk.sh}
SETTLE=${SETTLE:-2}          # seconds of quiet before acting
RETRY=${RETRY:-5}            # seconds before the second pass; 0 turns it off
LOG=${LOG:-$HOME/.cache/desk-watch.log}
LOCK=${LOCK:-$HOME/.cache/desk-watch.lock}

mkdir -p "$(dirname "$LOG")"
exec >>"$LOG" 2>&1

stamp() { date '+%F %T'; }

# i3 re-runs "exec" lines on every restart (mod+shift+r), not just at login,
# so without this a second restart leaves two watchers running side by side.
exec 9>"$LOCK" || { echo "$(stamp) cannot open $LOCK"; exit 1; }
if ! flock -n 9; then
	echo "$(stamp) another desk-watch.sh is already running, exiting"
	exit 0
fi

command -v xev >/dev/null || { echo "$(stamp) no xev (install x11-utils)"; exit 1; }
[ -x "$DESK" ] || { echo "$(stamp) $DESK is not executable"; exit 1; }

# 9>&- keeps the lock fd out of the children: otherwise one that lingers (xev,
# or anything desk.sh starts) would hold the lock after this process is gone,
# blocking every future start.  </dev/null keeps desk.sh and what it runs off
# the xev pipe inside the loop below, where stdin is the event stream.
desk() { "$DESK" "$@" </dev/null 9>&-; }

# Run desk.sh, wait RETRY seconds, run it again with -r so the wallpaper is
# repainted too (desk.sh cannot tell when it has been wiped).  Any arguments
# are a command to run just before the second pass.
desk_twice() {
	desk
	[ "$RETRY" -gt 0 ] 2>/dev/null || return 0
	sleep "$RETRY"
	"$@"
	echo "$(stamp) second pass after ${RETRY}s"
	desk -r
}

# Drop RandR events already queued on stdin.  They come from the first run's
# own xrandr call and the tail of the dock's burst, and the second pass is
# about to look at the current state anyway, so without this they would only
# set off a whole extra round once it finished.  Events that arrive once the
# second pass has started are left alone and handled normally.
drain() { while read -r -t 0.2 _; do :; done; }

echo "$(stamp) watching, settle=${SETTLE}s, retry=${RETRY}s"
desk_twice

xev -root -event randr 9>&- | while IFS= read -r line; do
	case $line in
	*RRScreenChangeNotify* | *RRNotify*) ;;
	*) continue ;;
	esac
	# Swallow the rest of the burst: read until SETTLE seconds of silence.
	while read -r -t "$SETTLE" _; do :; done
	echo "$(stamp) display change"
	desk_twice drain
done

echo "$(stamp) xev exited, stopping"
