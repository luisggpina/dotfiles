#!/bin/sh
#
# desk.sh -- idempotent X11 desk setup: displays, i3 workspaces
#
# Everything machine-specific is in the Configuration block below.  Displays
# are identified by EDID, output-name regex or preferred resolution -- never
# by a bare connector name, because those renumber between boots.
#
#   desk.sh              apply whatever needs applying
#   desk.sh -n           dry run: print what would change, change nothing
#   desk.sh -f           force everything, even if it already looks right
#   desk.sh -i           show what the script detects here (no changes)
#   desk.sh -l laptop    force a named layout
#   desk.sh -w           re-randomise wallpapers even if nothing else changed
#   desk.sh -r           repaint the last wallpapers (same images), for when
#                        something wiped them after the previous run
#   desk.sh -v           verbose: explain every decision
#
# Re-runnable at any time: each step compares before it acts, so a second run
# with nothing changed does nothing at all.
#
set -u

DRYRUN=0; FORCE=0; VERBOSE=0; DO_INFO=0; DO_WALL=0; DO_RESTORE=0; WANT_LAYOUT=''
CHANGED=0
FAILED=0
NL='
'

usage() { awk 'NR > 2 && /^#/ { sub(/^# ?/, ""); print; next } NR > 2 { exit }' "$0"; }
die()   { printf 'desk: %s\n' "$*" >&2; exit 1; }
fail()  { FAILED=$((FAILED + 1)); printf 'FAILED: %s\n' "$*" >&2; return 0; }
have()  { command -v "$1" >/dev/null 2>&1; }
act()   {
	CHANGED=$((CHANGED + 1))
	[ "$DRYRUN" = 1 ] && printf '(would) %s\n' "$*" || printf '%s\n' "$*"
	return 0
}
# stderr, not stdout: info is called from inside $(...) captures, and on
# stdout it would be swallowed into whatever the caller is collecting.
info()  { [ "$VERBOSE" = 1 ] && printf '    %s\n' "$*" >&2; return 0; }
run()   {
	if [ "$DRYRUN" = 1 ]; then
		printf '    [dry run] %s\n' "$*"
	else
		"$@"
	fi
}
runq() {
	if [ "$DRYRUN" = 1 ]; then
		printf '    [dry run] %s\n' "$*"
	else
		"$@" >/dev/null 2>&1
	fi
}
parse_args() {
	while [ $# -gt 0 ]; do
		case $1 in
		-n | --dry-run) DRYRUN=1 ;;
		-f | --force) FORCE=1 ;;
		-v | --verbose) VERBOSE=1 ;;
		-i | --info) DO_INFO=1 ;;
		-w | --wallpaper) DO_WALL=1 ;;
		-r | --restore-wallpaper) DO_RESTORE=1 ;;
		-l | --layout) shift; WANT_LAYOUT=${1-} ;;
		-h | --help) usage; exit 0 ;;
		*) die "unknown option: $1 (try -h)" ;;
		esac
		shift
	done
}

###############################################################################
# Configuration
###############################################################################

WALLPAPER_DIR="$HOME/wallpapers"

# --- how to recognise each display ------------------------------------------
# Columns: role, EDID substring, output-name regex, preferred resolution.
# "-" means "do not use this criterion".  They are tried in that order across
# ALL roles, so an EDID match anywhere beats a name match anywhere, which beats
# a resolution match.  Run "desk.sh -i" to see the EDID strings your displays
# advertise and paste a distinctive, space-free one into column 2 -- that is
# the sturdiest form of matching.
display_rules() {
	cat <<'EOF'
laptop   -  ^eDP-?[0-9]*$        -
monitor  -  ^DP-[0-9]+-[0-9]+$   3840x2160
tv       -  ^DP-[0-9]+$          4096x2160
EOF
}

# --- layouts ----------------------------------------------------------------
# Columns: role, mode, scale, XxY position, then any of "primary" and a
# rotation (normal/left/right/inverted) in either order.
# "auto" as the mode means "whatever this display says it prefers".
# The first layout whose displays are ALL connected wins, so keep the fullest
# one first and the laptop-only one last.
LAYOUTS='office desk laptop'

layout_office() {
	cat <<'EOF'
tv       4096x2160  1     0x0
monitor  3840x2160  1.25  4096x1228  primary
laptop   2880x1800  1.25  8896x1228
EOF
}
workspaces_office() {
	cat <<'EOF'
laptop   1 2 3
monitor  4 5 6
tv       8 9 10
EOF
}
focus_office() { echo '1 10 4'; }

# Docked, but the TV is not plugged in.
layout_desk() {
	cat <<'EOF'
monitor  3840x2160  1.25  0x0        primary
laptop   2880x1800  1.25  4800x225
EOF
}
workspaces_desk() {
	cat <<'EOF'
laptop   1 2 3
monitor  4 5 6 8 9 10
EOF
}
focus_desk() { echo '1 4'; }

layout_laptop() {
	cat <<'EOF'
laptop   auto  1  0x0  primary
EOF
}
workspaces_laptop() {
	cat <<'EOF'
laptop  1 2 3 4 5 6 7 8 9 10
EOF
}
focus_laptop() { echo '1'; }

###############################################################################
# Configuration accessors (turn the tables above into pipe-separated records)
###############################################################################

ROLES=$(display_rules | awk 'NF { print $1 }' | tr '\n' ' ')

# role|edid|name-regex|mode
cfg_display_rules() {
	display_rules | awk 'NF {
		for (i = 2; i <= 4; i++) if ($i == "-") $i = ""
		print $1 "|" $2 "|" $3 "|" $4
	}'
}
cfg_layout_names() { printf '%s\n' $LAYOUTS; }
# role|mode|scale|pos|rotate|primary
cfg_layout() {
	"layout_$1" | awk 'NF {
		rot = "normal"; prim = "false"
		for (i = 5; i <= NF; i++) {
			if ($i == "primary") prim = "true"
			else if ($i ~ /^(normal|left|right|inverted)$/) rot = $i
		}
		print $1 "|" $2 "|" $3 "|" $4 "|" rot "|" prim
	}'
}
cfg_layout_roles() { cfg_layout "$1" | cut -d'|' -f1; }
# role|workspace numbers
cfg_workspaces() {
	command -v "workspaces_$1" >/dev/null 2>&1 || return 0
	"workspaces_$1" | awk 'NF { r = $1; $1 = ""; sub(/^ +/, ""); print r "|" $0 }'
}
cfg_focus() {
	command -v "focus_$1" >/dev/null 2>&1 || return 0
	"focus_$1"
}

###############################################################################
# xrandr queries
###############################################################################

xr_refresh() { XR=$(xrandr --query); }

connected_outputs() {
	printf '%s\n' "$XR" | awk '
		$2 == "connected" { out = $1; want = 1; next }
		$2 == "disconnected" || $2 == "unknown" { want = 0; next }
		want && /^[ \t]/ {
			for (i = 2; i <= NF; i++)
				if ($i ~ /\+/) { print out, $1; want = 0; break }
		}'
}

all_outputs() {
	printf '%s\n' "$XR" |
		awk '$2 == "connected" || $2 == "disconnected" || $2 == "unknown" { print $1 }'
}

output_geometry() {
	printf '%s\n' "$XR" | awk -v o="$1" '
		$1 == o {
			for (i = 2; i <= NF; i++)
				if ($i ~ /^[0-9]+x[0-9]+\+[-0-9]+\+[-0-9]+$/) { print $i; exit }
			exit
		}'
}

output_current_mode() {
	printf '%s\n' "$XR" | awk -v o="$1" '
		$1 == o { want = 1; next }
		$2 == "connected" || $2 == "disconnected" || $2 == "unknown" { want = 0 }
		want && /^[ \t]/ {
			for (i = 2; i <= NF; i++)
				if ($i ~ /\*/) { print $1; exit }
		}'
}

output_is_primary() {
	printf '%s\n' "$XR" | awk -v o="$1" '$1 == o && $3 == "primary" { f = 1 } END { exit !f }'
}

output_rotation() {
	printf '%s\n' "$XR" | awk -v o="$1" '
		$1 == o {
			# stop at "(normal left inverted right ...)": that is the list of
			# rotations the output supports, not the one in effect
			for (i = 2; i <= NF; i++) {
				if ($i ~ /^\(/) break
				if ($i == "left" || $i == "right" || $i == "inverted") { print $i; exit }
			}
			print "normal"; exit
		}'
}

output_edid_text() {
	xrandr --props 2>/dev/null | awk -v o="$1" '
		$1 == o { cur = 1; ine = 0; next }
		$2 == "connected" || $2 == "disconnected" || $2 == "unknown" { cur = 0; ine = 0 }
		!cur { next }
		/EDID:/ { ine = 1; next }
		ine {
			gsub(/[ \t]/, "")
			if ($0 ~ /^[0-9a-fA-F]+$/ && length($0) >= 8) hex = hex $0
			else ine = 0
		}
		END {
			s = ""
			for (i = 1; i < length(hex); i += 2) {
				n = hv(substr(hex, i, 1)) * 16 + hv(substr(hex, i + 1, 1))
				s = s ((n >= 32 && n < 127) ? sprintf("%c", n) : "\n")
			}
			print s
		}
		function hv(c) { return index("0123456789abcdef", tolower(c)) - 1 }' |
		awk 'length($0) >= 4 { print }'
}

edid_matches() { output_edid_text "$1" | grep -qiF "$2"; }

# ceil(dimension * scale)
scale_dim() {
	awk -v d="$1" -v s="$2" 'BEGIN {
		v = d * s
		printf "%d", (v == int(v)) ? v : int(v) + 1
	}'
}

###############################################################################
# Role detection
###############################################################################

role_out()  { eval "printf '%s' \"\${ROLE_$1:-}\""; }
role_mode() { eval "printf '%s' \"\${MODE_$1:-}\""; }

# Three passes over the rules, so an EDID match anywhere beats a name match
# anywhere, which in turn beats a resolution match.  Otherwise the role listed
# first in the config would win on a weaker criterion.
detect_roles() {
	for dr_r in $ROLES; do
		eval "ROLE_$dr_r=''"
		eval "MODE_$dr_r=''"
	done
	UNKNOWN_OUTPUTS=''
	DR_RULES=$(cfg_display_rules)

	dr_ifs=$IFS
	IFS=$NL
	for dr_ln in $(connected_outputs); do
		IFS=$dr_ifs
		dr_out=${dr_ln%% *}
		dr_mode=${dr_ln##* }
		dr_role=''
		for dr_tier in edid name mode; do
			[ -n "$dr_role" ] && break
			dr_role=$(match_tier "$dr_out" "$dr_mode" "$dr_tier")
		done
		if [ -z "$dr_role" ]; then
			UNKNOWN_OUTPUTS="$UNKNOWN_OUTPUTS $dr_out($dr_mode)"
		elif [ -n "$(role_out "$dr_role")" ]; then
			UNKNOWN_OUTPUTS="$UNKNOWN_OUTPUTS $dr_out($dr_mode,also-$dr_role)"
		else
			eval "ROLE_$dr_role=\$dr_out"
			eval "MODE_$dr_role=\$dr_mode"
		fi
		IFS=$NL
	done
	IFS=$dr_ifs
}

match_tier() { # output, preferred mode, tier -> role or ""
	mt_out=$1 mt_mode=$2 mt_tier=$3
	mt_ifs=$IFS
	IFS=$NL
	for mt_rule in $DR_RULES; do
		IFS=$mt_ifs
		mt_role=${mt_rule%%|*}
		mt_rest=${mt_rule#*|}
		mt_edid=${mt_rest%%|*}
		mt_rest=${mt_rest#*|}
		mt_name=${mt_rest%%|*}
		mt_want=${mt_rest#*|}
		case $mt_tier in
		edid)
			[ -n "$mt_edid" ] && edid_matches "$mt_out" "$mt_edid" &&
				{ printf '%s' "$mt_role"; IFS=$mt_ifs; return 0; }
			;;
		name)
			[ -n "$mt_name" ] && printf '%s' "$mt_out" | grep -Eq "$mt_name" &&
				{ printf '%s' "$mt_role"; IFS=$mt_ifs; return 0; }
			;;
		mode)
			[ -n "$mt_want" ] && [ "$mt_want" = "$mt_mode" ] &&
				{ printf '%s' "$mt_role"; IFS=$mt_ifs; return 0; }
			;;
		esac
		IFS=$NL
	done
	IFS=$mt_ifs
	return 0
}

pick_layout() {
	for pl_l in $(cfg_layout_names); do
		pl_ok=1
		for pl_r in $(cfg_layout_roles "$pl_l"); do
			[ -n "$(role_out "$pl_r")" ] || pl_ok=0
		done
		[ "$pl_ok" = 1 ] && { printf '%s' "$pl_l"; return 0; }
	done
	return 1
}

###############################################################################
# Displays
###############################################################################

layout_plan() {
	lb_layout=$1
	XARGS=''
	XR_STALE=0
	lb_used=''
	lb_ifs=$IFS

	IFS=$NL
	for lb_ln in $(cfg_layout "$lb_layout"); do
		IFS=$lb_ifs
		lb_role=${lb_ln%%|*}; lb_r=${lb_ln#*|}
		lb_mode=${lb_r%%|*};  lb_r=${lb_r#*|}
		lb_scale=${lb_r%%|*}; lb_r=${lb_r#*|}
		lb_pos=${lb_r%%|*};   lb_r=${lb_r#*|}
		lb_rot=${lb_r%%|*}
		lb_prim=${lb_r##*|}

		lb_out=$(role_out "$lb_role")
		[ -n "$lb_out" ] || { IFS=$lb_ifs; die "layout '$lb_layout' wants '$lb_role', which is not connected"; }
		[ "$lb_mode" = auto ] && lb_mode=$(role_mode "$lb_role")

		# scale may be 1.25 or "1.25x1.25" or "2x2"
		case $lb_scale in
		*x*) lb_sx=${lb_scale%%x*}; lb_sy=${lb_scale##*x} ;;
		*) lb_sx=$lb_scale; lb_sy=$lb_scale ;;
		esac

		lb_x=${lb_pos%%x*}
		lb_y=${lb_pos##*x}
		lb_sw=$(scale_dim "${lb_mode%%x*}" "$lb_sx")
		lb_sh=$(scale_dim "${lb_mode##*x}" "$lb_sy")
		# a quarter turn swaps what xrandr reports as width and height
		case $lb_rot in
		left | right) lb_tmp=$lb_sw; lb_sw=$lb_sh; lb_sh=$lb_tmp ;;
		esac
		lb_want="${lb_sw}x${lb_sh}+${lb_x}+${lb_y}"

		XARGS="$XARGS$NL--output$NL$lb_out$NL--mode$NL$lb_mode$NL--pos$NL$lb_pos"
		XARGS="$XARGS$NL--rotate$NL$lb_rot$NL--scale$NL${lb_sx}x${lb_sy}"
		[ "$lb_prim" = true ] && XARGS="$XARGS$NL--primary"
		lb_used="$lb_used$NL$lb_out"

		lb_cur=$(output_geometry "$lb_out")
		if [ "$lb_cur" != "$lb_want" ]; then
			XR_STALE=1
			info "$lb_role ($lb_out): geometry ${lb_cur:-off} -> $lb_want"
		elif [ "$(output_current_mode "$lb_out")" != "$lb_mode" ]; then
			XR_STALE=1
			info "$lb_role ($lb_out): mode -> $lb_mode"
		elif [ "$(output_rotation "$lb_out")" != "$lb_rot" ]; then
			XR_STALE=1
			info "$lb_role ($lb_out): rotation -> $lb_rot"
		fi
		if [ "$lb_prim" = true ] && ! output_is_primary "$lb_out"; then
			XR_STALE=1
			info "$lb_role ($lb_out): should be primary"
		fi
		IFS=$NL
	done
	IFS=$lb_ifs

	for lb_o in $(all_outputs); do
		case "$lb_used$NL" in *"$NL$lb_o$NL"*) continue ;; esac
		if [ -n "$(output_geometry "$lb_o")" ]; then
			XR_STALE=1
			info "$lb_o: on, should be off"
		fi
		XARGS="$XARGS$NL--output$NL$lb_o$NL--off"
	done
}

layout_apply() {
	la_ifs=$IFS
	IFS=$NL
	# shellcheck disable=SC2086
	set -- $XARGS
	IFS=$la_ifs
	run xrandr "$@"
}

nitrogen_head() {
	xrandr --listmonitors 2>/dev/null | awk -v o="$1" '
		NR > 1 {
			idx = $1; sub(/:$/, "", idx)
			name = $2; sub(/^[+*]+/, "", name)
			if (name == o) { print idx; exit }
		}'
}

wallpapers_apply() {
	have nitrogen || return 0
	[ -n "$WALLPAPER_DIR" ] || return 0
	[ -d "$WALLPAPER_DIR" ] || { info "no $WALLPAPER_DIR, skipping wallpapers"; return 0; }
	wa_any=0
	for wa_r in $(cfg_layout_roles "$1"); do
		wa_head=$(nitrogen_head "$(role_out "$wa_r")")
		[ -n "$wa_head" ] || { info "no nitrogen head for $wa_r"; continue; }
		# --save records the pick in nitrogen's bg-saved.cfg, so that
		# wallpapers_restore (and "nitrogen --restore" in general) can repaint
		# these same images if something clears the root window later.
		run nitrogen --head="$wa_head" --random --set-auto --save "$WALLPAPER_DIR"
		wa_any=1
	done
	[ "$wa_any" = 1 ] && act "wallpapers: reshuffled"
	return 0
}

# Whether the wallpaper survived cannot be checked from here -- a cleared root
# window looks the same as a painted one to every query this script makes -- so
# this repaints unconditionally.  It is cheap and changes nothing on screen if
# the wallpaper was still there.
wallpapers_restore() {
	have nitrogen || return 0
	if runq nitrogen --restore; then
		act "wallpapers: restored"
	else
		fail "wallpapers: nitrogen --restore failed"
	fi
}

###############################################################################
# i3 workspaces
###############################################################################

i3_alive() { have i3-msg && i3-msg -t get_version >/dev/null 2>&1; }

i3_ws_outputs() {
	i3-msg -t get_workspaces 2>/dev/null | tr ',' '\n' |
		awk -F'"' '$2 == "num" { n = substr($3, 2) } $2 == "output" { print n, $4 }'
}

i3_focused_ws() {
	i3-msg -t get_workspaces 2>/dev/null | tr ',' '\n' |
		awk -F'"' '$2 == "num" { n = substr($3, 2) }
		           $2 == "focused" && $3 == ":true" { print n; exit }'
}

i3_apply() {
	ia_layout=$1
	ia_full=$2
	ia_map=$(cfg_workspaces "$ia_layout")
	[ -n "$ia_map" ] || return 0
	i3_alive || { info "i3 not running, skipping workspaces"; return 0; }

	ia_cur=$(i3_ws_outputs)
	ia_focus=$(i3_focused_ws)
	ia_moved=0
	ia_ifs=$IFS

	IFS=$NL
	for ia_ln in $ia_map; do
		IFS=$ia_ifs
		ia_role=${ia_ln%%|*}
		ia_list=${ia_ln#*|}
		ia_out=$(role_out "$ia_role")
		[ -n "$ia_out" ] || continue
		for ia_ws in $ia_list; do
			ia_on=$(printf '%s\n' "$ia_cur" | awk -v w="$ia_ws" '$1 == w { print $2 }')
			if [ "$ia_full" = 1 ]; then
				:
			elif [ -n "$ia_on" ] && [ "$ia_on" != "$ia_out" ]; then
				info "workspace $ia_ws drifted: $ia_on -> $ia_out"
			else
				continue
			fi
			runq i3-msg "workspace $ia_ws, move workspace to output $ia_out"
			ia_moved=1
		done
		IFS=$NL
	done
	IFS=$ia_ifs

	[ "$ia_moved" = 1 ] || return 0
	if [ "$ia_full" = 1 ]; then
		for ia_ws in $(cfg_focus "$ia_layout"); do
			runq i3-msg "workspace $ia_ws"
		done
		act "workspaces: pinned to $ia_layout layout"
	else
		[ -n "$ia_focus" ] && runq i3-msg "workspace $ia_focus"
		act "workspaces: moved back to the right outputs"
	fi
}

###############################################################################
# Reporting
###############################################################################

show_info() {
	printf 'connected displays:\n'
	si_ifs=$IFS
	IFS=$NL
	for si_ln in $(connected_outputs); do
		IFS=$si_ifs
		si_out=${si_ln%% *}
		si_mode=${si_ln##* }
		si_role='-'
		for si_r in $ROLES; do
			[ "$(role_out "$si_r")" = "$si_out" ] && si_role=$si_r
		done
		printf '  %-12s prefers %-11s now %-22s role=%s\n' \
			"$si_out" "$si_mode" "$(output_geometry "$si_out")" "$si_role"
		printf '    edid: %s\n' "$(output_edid_text "$si_out" | tr '\n' ' ')"
		IFS=$NL
	done
	IFS=$si_ifs
	[ -n "$UNKNOWN_OUTPUTS" ] && printf '  unidentified:%s\n' "$UNKNOWN_OUTPUTS"
	printf 'layouts: %s\n' "$(cfg_layout_names | tr '\n' ' ')"
	printf 'layout that would be used: %s\n' "$(pick_layout || echo 'none!')"
}

###############################################################################
# Main
###############################################################################

main() {
	parse_args "$@"
	: "${DISPLAY:=:0}"
	export DISPLAY
	have xrandr || die 'xrandr not found'

	xr_refresh
	detect_roles

	if [ "$DO_INFO" = 1 ]; then
		show_info
		exit 0
	fi

	if [ -n "$WANT_LAYOUT" ]; then
		layout=$WANT_LAYOUT
		cfg_layout_names | grep -qx "$layout" || die "no layout '$layout' for this host"
	else
		layout=$(pick_layout) || die "no layout matches what is plugged in (try -i)"
	fi

	printf 'layout: %s (' "$layout"
	for r in $(cfg_layout_roles "$layout"); do printf '%s=%s ' "$r" "$(role_out "$r")"; done
	printf ')\n'
	if [ -n "$UNKNOWN_OUTPUTS" ]; then
		printf 'note: unidentified displays, left off:%s\n' "$UNKNOWN_OUTPUTS"
		printf '      run "%s -i" and add an edid or name rule for them\n' "${0##*/}"
	fi
	for r in $ROLES; do
		[ -n "$(role_out "$r")" ] || continue
		case " $(cfg_layout_roles "$layout" | tr '\n' ' ')" in
		*" $r "*) ;;
		*) printf 'note: %s (%s) is connected but not in this layout, leaving it off\n' \
			"$r" "$(role_out "$r")" ;;
		esac
	done

	layout_plan "$layout"
	[ "$FORCE" = 1 ] && XR_STALE=1
	if [ "$XR_STALE" = 1 ]; then
		if layout_apply; then
			act "displays: applied $layout layout"
			xr_refresh
			i3_apply "$layout" 1
			wallpapers_apply "$layout"
		else
			fail "displays: xrandr rejected the $layout layout"
		fi
	else
		info 'displays: already correct'
		i3_apply "$layout" 0
		if [ "$DO_WALL" = 1 ]; then
			wallpapers_apply "$layout"
		elif [ "$DO_RESTORE" = 1 ]; then
			wallpapers_restore
		fi
	fi

	[ "$CHANGED" = 0 ] && [ "$FAILED" = 0 ] && printf 'nothing to do.\n'
	[ "$FAILED" = 0 ] || return 1
	return 0
}

main "$@"
exit $?
