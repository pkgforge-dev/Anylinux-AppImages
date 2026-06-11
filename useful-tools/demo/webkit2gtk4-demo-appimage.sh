#!/bin/sh

# Demonstration that bundles a simple webkit2gtk4.1 app

set -eux

ARCH="$(uname -m)"
SHARUN="https://raw.githubusercontent.com/${GITHUB_REPOSITORY%/*}/${GITHUB_REPOSITORY#*/}/refs/heads/main/useful-tools/quick-sharun.sh"
EXTRA_PACKAGES="https://raw.githubusercontent.com/${GITHUB_REPOSITORY%/*}/${GITHUB_REPOSITORY#*/}/refs/heads/main/useful-tools/get-debloated-pkgs.sh"

export ICON=https://github.com/webkit.png
export DESKTOP=DUMMY
export OUTPATH=./dist
export OUTNAME=webkit2gtk4-demo-"$ARCH".AppImage
export MAIN_BIN=webkit2gtk4-demo
export GTK_CLASS_FIX=1

pacman -Syu --noconfirm \
	base-devel       \
	git              \
	gtk3             \
	webkit2gtk-4.1   \
	libxcb           \
	libxcursor       \
	libxi            \
	libxkbcommon     \
	libxkbcommon-x11 \
	libxrandr        \
	libxtst          \
	wget             \
	xorg-server-xvfb \
	zsync

echo "Installing debloated packages..."
echo "---------------------------------------------------------------"
wget --retry-connrefused --tries=30 "$EXTRA_PACKAGES" -O ./get-debloated-pkgs.sh
chmod +x ./get-debloated-pkgs.sh
./get-debloated-pkgs.sh --add-common --prefer-nano webkit2gtk-4.1-mini

echo "Building webkit2gtk4-demo..."
echo "---------------------------------------------------------------"
cat > webkit2gtk4-demo.c << 'EOF'
#include <gtk/gtk.h>
#include <webkit2/webkit2.h>

static void destroy_cb(GtkWidget *widget, gpointer data) {
	(void)widget;
	(void)data;
	gtk_main_quit();
}

int main(int argc, char *argv[]) {
	gtk_init(&argc, &argv);

	GtkWidget *window = gtk_window_new(GTK_WINDOW_TOPLEVEL);
	gtk_window_set_title(GTK_WINDOW(window), "webkit2gtk Demo - Anylinux AppImages");
	gtk_window_set_default_size(GTK_WINDOW(window), 1024, 768);

	WebKitWebView *webview = WEBKIT_WEB_VIEW(webkit_web_view_new());
	webkit_web_view_load_uri(webview, "https://pkgforge-dev.github.io/Anylinux-AppImages/");

	gtk_container_add(GTK_CONTAINER(window), GTK_WIDGET(webview));

	g_signal_connect(G_OBJECT(window), "destroy", G_CALLBACK(destroy_cb), NULL);

	gtk_widget_show_all(window);
	gtk_main();

	return 0;
}
EOF

cc -O2 -o webkit2gtk4-demo webkit2gtk4-demo.c $(pkg-config --cflags --libs webkit2gtk-4.1 gtk+-3.0)

echo "Bundling AppImage..."
echo "---------------------------------------------------------------"
wget --retry-connrefused --tries=30 "$SHARUN" -O ./quick-sharun
chmod +x ./quick-sharun
./quick-sharun ./webkit2gtk4-demo

./quick-sharun --make-appimage

# test the final app
./quick-sharun --test ./dist/*.AppImage
