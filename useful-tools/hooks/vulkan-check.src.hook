#!/bin/sh
set -e
# hook that checks several potential issues vulkan related

# On aarch64 device drivers are all over the place and often they ship with
# modifications not upstreamed to mesa, so we need to allow the host vulkan

_vulkan_hook_dir=${TMPDIR:-/tmp}/.vulkan-hook

if [ "$APPIMAGE_ARCH" = 'aarch64' ]; then
	export SHARUN_ALLOW_SYS_VKICD=${SHARUN_ALLOW_SYS_VKICD:-1}
fi

_nvidia_check() (
	# wtf makes this file? I cannot find any info related to it!
	nonsense=/usr/share/vulkan/icd.d/nvidia_icd.json_inactive
	if [ -f "$nonsense" ]; then
		err_msg ""
		err_msg "WARNING: Nvidia vulkan driver disabled by '$nonsense'"
		err_msg ""
		return 1
	fi

	# debian likes to split the nvidia driver into several packages
	# so there is a lot of people that only have the nvidia opengl driver installed
	# that then come complain that X vulkan app does not work because there is
	# no nvidia vulkan driver installed on their system.
	set -- /usr/share/glvnd/egl_vendor.d/10_nvidia.json /usr/share/vulkan/icd.d/*nvidia*.json
	if [ -f "$1" ] && [ ! -f "$2" ]; then
		err_msg ""
		err_msg "============================================================"
		err_msg ""
		err_msg "YOU HAVE AN INCOMPLETE NVIDIA DRIVER INSTALLATION!"
		err_msg ""
		err_msg "There is no nvidia vulkan loader at: /usr/share/vulkan/icd.d"
		err_msg "This usually happens when you are using a distro that splits"
		err_msg "the nvidia driver into several packages such as debian"
		err_msg "Run 'sudo apt install nvidia-vulkan-icd' to fix this issue"
		err_msg ""
		err_msg "MAKE SURE YOUR VULKAN DRIVER WORKS BEFORE REPORTING BUGS"
		err_msg "You can check that by testing with vkcube"
		err_msg ""
		err_msg "============================================================"
		err_msg ""
	elif [ -f "$1" ] || [ -f "$2" ]; then
		return 0
	fi
	return 1
)

_nvidia_check || :

# It is possible for a vulkan layer to have a path with '$LIB' which is a token
# used by the dynamic linker that expands to locations like lib and lib32
# the problem here is that debian  has lib/x86_64-linux-gnu instead
# so we need to check and patch '$LIB' for the real path to the lib instead
_check_vulkan_json_path() (
	implicit_dir=$_vulkan_hook_dir/vulkan/implicit_layer.d
	explicit_dir=$_vulkan_hook_dir/vulkan/explicit_layer.d

	is_cmd grep sed mkdir || return 1

	for f in /usr/share/vulkan/explicit_layer.d/*; do
		if [ -f "$f" ] && layer_path=$(grep -o '"/usr.*$LIB.*"' "$f"); then
			for p in lib/"$APPIMAGE_ARCH"-linux-gnu lib64 lib; do
				test_path=$(echo "$layer_path" | sed "s|\"||g; s|\$LIB|$p|")
				if [ -e "$test_path" ]; then
					mkdir -p "$explicit_dir"
					# sed -i is not POSIX
					__tmp_sed=$(sed "s|\$LIB|$p|" "$f")
					echo "$__tmp_sed" > "$explicit_dir"/"${f##*/}"
					>&2 echo "vulkan-check: Handled \$LIB path in $f"
					break
				fi
			done
		fi
	done

	for f in /usr/share/vulkan/implicit_layer.d/*; do
		if [ -f "$f" ] && layer_path=$(grep -o '"/usr.*$LIB.*"' "$f"); then
			for p in lib/"$APPIMAGE_ARCH"-linux-gnu lib64 lib; do
				test_path=$(echo "$layer_path" | sed "s|\"||g; s|\$LIB|$p|")
				if [ -e "$test_path" ]; then
					mkdir -p "$implicit_dir"
					# sed -i is not POSIX
					__tmp_sed=$(sed "s|\$LIB|$p|" "$f")
					echo "$__tmp_sed" > "$implicit_dir"/"${f##*/}"
					>&2 echo "vulkan-check: Handled \$LIB path in $f"
					break
				fi
			done
		fi
	done
)

if _check_vulkan_json_path && [ -d "$_vulkan_hook_dir" ]; then
	export XDG_CONFIG_DIRS="$_vulkan_hook_dir:${XDG_CONFIG_DIRS:-/etc/xdg}"
fi

_start_virtualization() {
	set -- /dev/dri/render*
	gpu=$1

	set -- "$APPDIR"/share/vulkan/icd.d/virtio_icd*.json
	virtio_icd=$1

	set -- "$APPDIR"/share/glvnd/egl_vendor.d/*_mesa.json
	mesa_icd=$1

	if ! command -v virgl_test_server 1>/dev/null; then
		err_msg "ERROR: No virgl_test_server binary found!"
		return 1
	elif [ ! -e "$gpu" ]; then
		err_msg "ERROR: There is no gpu in this system!"
		return 1
	elif [ ! -e "$virtio_icd" ]; then
		err_msg "ERROR: Vulkan virtio was not bundled! Cannot continue."
		return 1
	elif [ ! -e "$mesa_icd" ]; then
		err_msg "ERROR: Mesa gallium was not bundled! Cannot continue."
		return 1
	fi

	socket=${TMPDIR:-/tmp}/virgl.socket
	virgl_test_server --venus --use-gles --socket-path "$socket" --rendernode "$gpu" &

	export VTEST_SOCKET_NAME="$socket"
	export VK_DRIVER_FILES="$virtio_icd"
	export __GLX_VENDOR_LIBRARY_NAME=mesa
	export __EGL_VENDOR_LIBRARY_FILENAMES="$mesa_icd"
	export MESA_LOADER_DRIVER_OVERRIDE=zink
	export SHARUN_ALLOW_SYS_VKICD=0

	# TODO: Improve this check, this is only a problem that affects the amdgpu ddx
	case "$XDG_SESSION_TYPE" in
		x11|X11) export LIBGL_KOPPER_DRI2=1;;
	esac
}

if [ "$ENABLE_VIRTUALIZATION_THIS_IS_EXPERIMENTAL_KEK" = 1 ]; then
	>&2 echo "Starting virtualization"
	_start_virtualization || :
fi
