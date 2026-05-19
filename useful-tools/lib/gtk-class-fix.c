/*
 * GTK Window Class Override + Glycin Sandbox Disable
 * ===================================================
 *
 * PURPOSE:
 *  GNOME made the window class of applications different between x11 and
 *  wayland, breaking desktop integration of appimages as result.
 *
 *  Glycin forces sandboxing which fails 100% of the time here because the
 *  library is horribly written and does not resolve the full path of the
 *  binaries it passes to bwrap, it does not even check if bwrap is present!
 *
 * USAGE:
 *   GTK_WINDOW_CLASS=fuck.gnome LD_PRELOAD=./gtk-class-fix.so /path/to/app
 *
 * WARNING:
 *  This was 100% vibed with AI by someone that has no idea about C
 *  It works, but no idea if this can cause weird issues down the line
*/

#define _GNU_SOURCE
#include <dlfcn.h>
#include <stdio.h>
#include <stdlib.h>

/* ------------------------------------------------------------------ */
/*  GTK / GLib window-class overrides                                 */
/* ------------------------------------------------------------------ */

typedef struct _GApplication GApplication;
typedef unsigned int GApplicationFlags;

static const char *override_id = NULL;

static GApplication *(*real_g_application_new)(const char *, GApplicationFlags);
static GApplication *(*real_gtk_application_new)(const char *, GApplicationFlags);
static void (*real_g_application_set_application_id)(GApplication *, const char *);
static void (*real_g_set_prgname)(const char *);
static const char *(*real_g_get_prgname)(void);
static void (*real_gdk_surface_set_app_id)(void *surface, const char *app_id);
static void (*real_gdk_wayland_window_set_app_id)(void *window, const char *app_id);
static void (*real_gdk_window_set_app_id)(void *window, const char *app_id);

static int gtk_init_done = 0;

static void gtk_init(void) {
	if (__atomic_load_n(&gtk_init_done, __ATOMIC_ACQUIRE)) return;

	override_id = getenv("GTK_WINDOW_CLASS");
	if (override_id && *override_id) {
		fprintf(stderr, " [gtk-class-fix.so] Setting window class to '%s'\n", override_id);
	} else {
		override_id = NULL;
	}

	real_g_application_new = dlsym(RTLD_NEXT, "g_application_new");
	real_gtk_application_new = dlsym(RTLD_NEXT, "gtk_application_new");
	real_g_application_set_application_id = dlsym(RTLD_NEXT, "g_application_set_application_id");
	real_g_set_prgname = dlsym(RTLD_NEXT, "g_set_prgname");
	real_g_get_prgname = dlsym(RTLD_NEXT, "g_get_prgname");
	real_gdk_surface_set_app_id = dlsym(RTLD_NEXT, "gdk_surface_set_app_id");
	real_gdk_wayland_window_set_app_id = dlsym(RTLD_NEXT, "gdk_wayland_window_set_app_id");
	real_gdk_window_set_app_id = dlsym(RTLD_NEXT, "gdk_window_set_app_id");
	__atomic_store_n(&gtk_init_done, 1, __ATOMIC_RELEASE);
}

static const char *effective_id(const char *requested) {
	return override_id ? override_id : requested;
}

GApplication *g_application_new(const char *application_id, GApplicationFlags flags) {
	gtk_init();
	return real_g_application_new ? real_g_application_new(effective_id(application_id), flags) : NULL;
}

GApplication *gtk_application_new(const char *application_id, GApplicationFlags flags) {
	gtk_init();
	return real_gtk_application_new ? real_gtk_application_new(effective_id(application_id), flags) : NULL;
}

void g_application_set_application_id(GApplication *app, const char *application_id) {
	gtk_init();
	if (real_g_application_set_application_id) {
		real_g_application_set_application_id(app, effective_id(application_id));
	}
}

void g_set_prgname(const char *prgname) {
	gtk_init();
	if (real_g_set_prgname) {
		real_g_set_prgname(effective_id(prgname));
	}
}

const char *g_get_prgname(void) {
	gtk_init();
	if (override_id) return override_id;
	return real_g_get_prgname ? real_g_get_prgname() : NULL;
}

void gdk_surface_set_app_id(void *surface, const char *app_id) {
	gtk_init();
	if (real_gdk_surface_set_app_id) {
		real_gdk_surface_set_app_id(surface, effective_id(app_id));
	}
}

void gdk_wayland_window_set_app_id(void *window, const char *app_id) {
	gtk_init();
	if (real_gdk_wayland_window_set_app_id) {
		real_gdk_wayland_window_set_app_id(window, effective_id(app_id));
	}
}

void gdk_window_set_app_id(void *window, const char *app_id) {
	gtk_init();
	if (real_gdk_window_set_app_id) {
		real_gdk_window_set_app_id(window, effective_id(app_id));
	}
}

/* ------------------------------------------------------------------ */
/*  Glycin sandbox disable                                            */
/* ------------------------------------------------------------------ */

typedef void* (*gly_loader_new_t)(void*);
typedef void* (*gly_loader_new_for_stream_t)(void*);
typedef void* (*gly_loader_new_for_bytes_t)(void*);
typedef void (*gly_loader_set_sandbox_selector_t)(void*, int);

#ifndef GLY_SANDBOX_SELECTOR_NOT_SANDBOXED
#define GLY_SANDBOX_SELECTOR_NOT_SANDBOXED 3
#endif

static int gly_init_done = 0;
static gly_loader_set_sandbox_selector_t real_gly_set_sandbox_selector = NULL;

static void gly_init(void) {
	if (__atomic_load_n(&gly_init_done, __ATOMIC_ACQUIRE)) return;
	real_gly_set_sandbox_selector = dlsym(RTLD_NEXT, "gly_loader_set_sandbox_selector");
	if (!real_gly_set_sandbox_selector)
		real_gly_set_sandbox_selector = dlsym(RTLD_DEFAULT, "gly_loader_set_sandbox_selector");
	__atomic_store_n(&gly_init_done, 1, __ATOMIC_RELEASE);
}

static void force_not_sandboxed(void *loader) {
	gly_init();
	if (real_gly_set_sandbox_selector && loader)
		real_gly_set_sandbox_selector(loader, GLY_SANDBOX_SELECTOR_NOT_SANDBOXED);
}

static void* get_real_gly(const char *name) {
	void *sym = dlsym(RTLD_NEXT, name);
	if (!sym) sym = dlsym(RTLD_DEFAULT, name);
	return sym;
}

void* gly_loader_new(void* file) {
	static gly_loader_new_t real = NULL;
	if (!real) real = (gly_loader_new_t)get_real_gly("gly_loader_new");
	void *loader = real ? real(file) : NULL;
	if (loader) force_not_sandboxed(loader);
	return loader;
}

void* gly_loader_new_for_stream(void* stream) {
	static gly_loader_new_for_stream_t real = NULL;
	if (!real) real = (gly_loader_new_for_stream_t)get_real_gly("gly_loader_new_for_stream");
	void *loader = real ? real(stream) : NULL;
	if (loader) force_not_sandboxed(loader);
	return loader;
}

void* gly_loader_new_for_bytes(void* bytes) {
	static gly_loader_new_for_bytes_t real = NULL;
	if (!real) real = (gly_loader_new_for_bytes_t)get_real_gly("gly_loader_new_for_bytes");
	void *loader = real ? real(bytes) : NULL;
	if (loader) force_not_sandboxed(loader);
	return loader;
}

/* ------------------------------------------------------------------ */
/*  Constructor                                                       */
/* ------------------------------------------------------------------ */

__attribute__((constructor))
static void gtk_class_fix_ctor(void) {
	gtk_init();
	if (override_id && real_g_set_prgname) {
		real_g_set_prgname(override_id);
	}
}
