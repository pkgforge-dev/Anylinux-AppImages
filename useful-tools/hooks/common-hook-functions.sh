#!/bin/sh

set -e

HOST_HOME=${REAL_HOME:-$HOME}
HOST_XDG_CONFIG_HOME=${REAL_XDG_CONFIG_HOME:-${XDG_CONFIG_HOME:-$HOST_HOME/.config}}
HOST_XDG_DATA_HOME=${REAL_XDG_DATA_HOME:-${XDG_DATA_HOME:-$HOST_HOME/.local/share}}
HOST_XDG_CACHE_HOME=${REAL_XDG_CACHE_HOME:-${XDG_CACHE_HOME:-$HOST_HOME/.cache}}
HOST_XDG_STATE_HOME=${REAL_XDG_STATE_HOME:-${XDG_STATE_HOME:-$HOST_HOME/.local/state}}

export HOST_HOME HOST_XDG_CONFIG_HOME HOST_XDG_DATA_HOME HOST_XDG_CACHE_HOME HOST_XDG_STATE_HOME

BINDIR=${XDG_BIN_HOME:-~/.local/bin}
DATADIR=${XDG_DATA_HOME:-~/.local/share}
CONFIGDIR=${XDG_CONFIG_HOME:-~/.config}
CACHEDIR=${XDG_CACHE_HOME:-~/.cache}
STATEDIR=${XDG_STATE_HOME:-~/.local/state}

APPLICATION_NAME=${APPIMAGE##*/}

err_msg(){
	>&2 printf '\033[1;31m%s\033[0m\n' " $*"
}

is_cmd() {
	if [ "$1" --any ]; then
		shift
		for cmd do
			if command -v "$cmd" 1>/dev/null; then
				return 0
			fi
		done
		return 1
	else
		for cmd do
			command -v "$cmd" 1>/dev/null || return 1
		done
	fi
	return 0
}

run_gui_sudo() {
	_sudocmd=""
	if   _sudocmd=$(command -v pkexec);    then :
	elif _sudocmd=$(command -v lxqt-sudo); then :
	elif _sudocmd=$(command -v run0);      then set -- --via-shell "$@"
	fi
	if [ "$1" = --check ]; then
		[ -n "$_sudocmd" ] || return 1
	else
		if [ -z "$_sudocmd" ]; then
			err_msg "We need 'pkexec' or 'lxqt-sudo' or 'run0' to perform this operation"
			return 1
		fi
	fi
	"$_sudocmd" "$@"
}

download() {
	if   _download_cmd=$(command -v wget); then set -- -O "$@"
	elif _download_cmd=$(command -v curl); then set -- -Lo "$@"
	else
		err_msg "We need 'wget' or 'curl' or 'aria2c' to download $1"
		return 1
	fi
	log=${TMPDIR:-/tmp}/._download.log
	if ! "$_download_cmd" "$@" 2>"$log"; then
		cat "$log"
		err_msg "Download failed!"
		return 1
	fi
	rm -f "$log"
}


# the following function are used by notify

# display functions, these might return non 0 depending on user input
_display_info() {
	set -- "INFO: $*"
	if   is_cmd kdialog;   then kdialog --msgbox "$*"
	elif is_cmd qarma;     then qarma --info --text "$*"
	elif is_cmd yad;       then yad --info --text "$*"
	elif is_cmd zenity;    then zenity --info --text "$*"
	elif is_cmd Xdialog;   then Xdialog --infobox "$*" 0 0 6000
	elif is_cmd gxmessage; then gxmessage -center "$*"
	elif is_cmd xmessage;  then xmessage -center "$*"
	else _notification=0   _display_with_host_term "$*"
	fi
}

_display_error() {
	set -- "ERROR: $*"
	if   is_cmd kdialog;   then kdialog --error "$*"
	elif is_cmd qarma;     then qarma --error --text "$*"
	elif is_cmd yad;       then yad --error --text "$*"
	elif is_cmd zenity;    then zenity --error --text "$*"
	elif is_cmd Xdialog;   then Xdialog --msgbox "$*" 0 0
	elif is_cmd gxmessage; then gxmessage -center "$*"
	elif is_cmd xmessage;  then xmessage -center "$*"
	else _notification=0   _display_with_host_term "$*"
	fi
}

_display_warning() {
	set -- "WARNING: $*"
	if   is_cmd kdialog;   then kdialog --sorry "$*"
	elif is_cmd qarma;     then qarma --warning --text "$*"
	elif is_cmd yad;       then yad --warning --text "$*"
	elif is_cmd zenity;    then zenity --warning --text "$*"
	elif is_cmd Xdialog;   then Xdialog --msgbox "$*" 0 0
	elif is_cmd gxmessage; then gxmessage -center "$*"
	elif is_cmd xmessage;  then xmessage -center "$*"
	else _notification=0    _display_with_host_term "$*"
	fi
}

_display_question() {
	set -- "QUESTION: $*"
	if   is_cmd kdialog;   then kdialog --yesno "$*"
	elif is_cmd qarma;     then qarma --question --text "$*"
	elif is_cmd yad;       then yad --question --text "$*"
	elif is_cmd zenity;    then zenity --question --text "$*"
	elif is_cmd Xdialog;   then Xdialog --yesno "$*" 0 0
	elif is_cmd gxmessage; then gxmessage -center -buttons "Yes:0,No:1" "$*"
	elif is_cmd xmessage;  then xmessage -center -buttons "Yes:0,No:1" "$*"
	else _notification=0    _display_with_host_term "$*"
	fi
}

# notify functions, these will always return 0 unless there are no deps
_notify_info() {
	set -- "INFO: $*"
	if   is_cmd notify-send; then notify-send "$*" || :
	elif is_cmd qarma;       then qarma --info --text "$*" || :
	elif is_cmd kdialog;     then kdialog --passivepopup "$*" || :
	elif is_cmd yad;         then yad --window-type=notification --text "$*" || :
	elif is_cmd zenity;      then zenity --info --text "$*" || :
	elif is_cmd Xdialog;     then Xdialog --infobox "$*" 0 0 6000 || :
	elif is_cmd xmessage;    then xmessage -center "$*" || :
	elif is_cmd gxmessage;   then gxmessage -center "$*" || :
	else _notification=1     _display_with_host_term "$*"
	fi
}

_notify_error() {
	set -- "ERROR: $*"
	if   is_cmd notify-send; then notify-send -u critical "$*" || :
	elif is_cmd kdialog;     then kdialog --error "$*" || :
	elif is_cmd qarma;       then qarma --error --text "$*" || :
	elif is_cmd yad;         then yad --window-type=notification --text "$*" || :
	elif is_cmd zenity;      then zenity --error --text "$*" || :
	elif is_cmd Xdialog;     then Xdialog --infobox "$*" 0 0 6000 || :
	elif is_cmd xmessage;    then xmessage -center "$*" || :
	elif is_cmd gxmessage;   then gxmessage -center "$*" || :
	else _notification=1     _display_with_host_term "$*"
	fi
}

_notify_warning() {
	set -- "WARNING: $*"
	if   is_cmd notify-send; then notify-send -u critical "$*" || :
	elif is_cmd kdialog;     then kdialog --sorry "$*" || :
	elif is_cmd qarma;       then qarma --warning --text "$*" || :
	elif is_cmd yad;         then yad --window-type=notification --text "$*" || :
	elif is_cmd zenity;      then zenity --warning --text "$*" || :
	elif is_cmd Xdialog;     then Xdialog --infobox "$*" 0 0 6000 || :
	elif is_cmd gxmessage;   then gxmessage -center "$*" || :
	elif is_cmd xmessage;    then xmessage -center "$*" || :
	else _notification=1     _display_with_host_term "$*"
	fi
}

# extreme measure
_display_with_host_term() {
	message=$*
	tmpfile=${TMPDIR:-/tmp}/.${0##*/}-no-gui-fallback

	cmd_notification="echo '$message'; read yn"
	cmd_display="
		trap 'echo 0 > \"$tmpfile\"; exit' HUP TERM
		echo '$message'
		printf '\n%s''   (Yes/No)?: ';
		while :; do
			read yn
			case \$yn in
				Y*|y*) echo 1 > '$tmpfile'; break;;
				N*|n*) echo 0 > '$tmpfile'; break;;
				*)     echo 'Please type Yes or No' ;;
			esac
		done
	"

	if [ "$_notification" = 1 ]; then
		tcmd="$cmd_notification"
	else
		tcmd="$cmd_display"
	fi

	# normal terminals
	if   is_cmd alacritty;  then alacritty  -e sh -c "$tcmd" &
	elif is_cmd wezterm;    then wezterm    -e sh -c "$tcmd" &
	elif is_cmd konsole;    then konsole    -e sh -c "$tcmd" &
	elif is_cmd lxterminal; then lxterminal -e sh -c "$tcmd" &
	elif is_cmd kitty;      then kitty      -e sh -c "$tcmd" &
	elif is_cmd urxvt;      then urxvt      -e sh -c "$tcmd" &
	elif is_cmd xterm;      then xterm      -e sh -c "$tcmd" &
	# mmmm
	elif is_cmd gnome-terminal; then gnome-terminal -- sh -c "$tcmd" &
	# these need extra quotes for some reason
	elif is_cmd ptyxis;         then ptyxis         -x "sh -c \"$tcmd\"" &
	elif is_cmd qterminal;      then qterminal      -e "sh -c \"$tcmd\"" &
	elif is_cmd mate-terminal;  then mate-terminal  -e "sh -c \"$tcmd\"" &
	elif is_cmd xfce4-terminal; then xfce4-terminal -e "sh -c \"$tcmd\"" &
	else
		err_msg "Cannot find suitable binary to perform operation!"
		return 127
	fi

	if [ "$_notification" = 1 ]; then
		return 0
	fi

	_elapsed=0
	_timeout=150  # 15 seconds
	while :; do
		if [ -f "$tmpfile" ] || [ "$_elapsed" -ge "$_timeout" ]; then
			break
		fi
		sleep 0.1
		_elapsed=$(( _elapsed + 1 ))
	done

	read -r _reply < "$tmpfile"
	rm -f "$tmpfile"

	if [ "$_reply" = "1" ]; then
		return 0
	else
		return 1
	fi
}

notify() {
	case "$1" in
		--display-info|-di)     shift; _display_info     "$@";;
		--display-error|-de)    shift; _display_error    "$@";;
		--display-warning|-dw)  shift; _display_warning  "$@";;
		--display-question|-dq) shift; _display_question "$@";;
		--notify-info|-ni)      shift; _notify_info      "$@";;
		--notify-error|-ne)     shift; _notify_error     "$@";;
		--notify-warning|-nw)   shift; _notify_warning   "$@";;
		# act as notify-send ARG wrapper when no flag is given
		*) _notify_info "$@";;
	esac
}

