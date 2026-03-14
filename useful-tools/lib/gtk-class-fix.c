/*
 * GTK Window Class Override
 * =========================
 *
 * PURPOSE:
 *  GNOME decided to make the  window class of applications different
 *  between x11 and wayland, breaking desktop integration of appimages
 *  as result
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
#include <stdarg.h>
#include <stdio.h>
#include <stdlib.h>
#include <string.h>

typedef void           *gpointer;
typedef unsigned long   GType;
typedef unsigned int    guint;
typedef int             gboolean;
typedef char            gchar;
typedef struct _GObject      GObject;
typedef struct _GApplication GApplication;
typedef unsigned int    GApplicationFlags;
typedef struct _GValue GValue;

static GType     (*fn_g_application_get_type)(void);
static gboolean  (*fn_g_type_check_instance_is_a)(gpointer, GType);
static const char *(*fn_g_application_get_application_id)(GApplication *);

#define G_IS_APPLICATION(o) \
    (fn_g_application_get_type && fn_g_type_check_instance_is_a && \
     fn_g_type_check_instance_is_a((gpointer)(o), fn_g_application_get_type()))
#define G_APPLICATION(o) ((GApplication *)(o))
#define G_OBJECT(o)      ((GObject *)(o))


static const char *override_id      = NULL;
static int         override_checked = 0;
static int         in_override      = 0;
static GApplication *(*real_g_application_new)(const char *, GApplicationFlags);
static GApplication *(*real_gtk_application_new)(const char *, GApplicationFlags);
static void          (*real_g_application_set_application_id)(GApplication *, const char *);
static void          (*real_g_set_prgname)(const char *);
static const char   *(*real_g_get_prgname)(void);

#define LOAD(sym) \
    do { if (!real_##sym) real_##sym = (__typeof__(real_##sym))dlsym(RTLD_NEXT, #sym); } while (0)
#define LOAD_FN(dst, name) \
    do { if (!dst) *(void **)(&dst) = dlsym(RTLD_NEXT, name); } while (0)

static void init_override_id(void) {
    if (override_checked) return;
    override_checked = 1;
    override_id = getenv("GTK_WINDOW_CLASS");
    if (override_id && *override_id)
        fprintf(stderr, " [gtk-class-fix.so] Setting window class to '%s'\n", override_id);
}

static const char *effective_id(const char *requested) {
    init_override_id();
    return (override_id && *override_id) ? override_id : requested;
}

static void resolve(void) {
    LOAD(g_application_new);
    LOAD(gtk_application_new);
    LOAD(g_application_set_application_id);
    LOAD(g_set_prgname);
    LOAD(g_get_prgname);
    LOAD_FN(fn_g_application_get_type,          "g_application_get_type");
    LOAD_FN(fn_g_type_check_instance_is_a,      "g_type_check_instance_is_a");
    LOAD_FN(fn_g_application_get_application_id, "g_application_get_application_id");
}

static void maybe_override(GApplication *app) {
    if (!app || in_override) return;
    init_override_id();
    if (!override_id || !*override_id) return;

    if (fn_g_application_get_application_id) {
        const char *current_id = fn_g_application_get_application_id(app);
        if (current_id && strcmp(current_id, override_id) == 0) return;
    }

    in_override = 1;
    if (real_g_application_set_application_id)
        real_g_application_set_application_id(app, override_id);
    if (real_g_set_prgname)
        real_g_set_prgname(override_id);
    in_override = 0;
}

GApplication *g_application_new(const char *application_id, GApplicationFlags flags) {
    resolve();
    GApplication *app = real_g_application_new
        ? real_g_application_new(effective_id(application_id), flags) : NULL;
    maybe_override(app);
    return app;
}

GApplication *gtk_application_new(const char *application_id, GApplicationFlags flags) {
    resolve();
    GApplication *app = real_gtk_application_new
        ? real_gtk_application_new(effective_id(application_id), flags) : NULL;
    maybe_override(app);
    return app;
}

void g_application_set_application_id(GApplication *app, const char *application_id) {
    resolve();
    if (real_g_application_set_application_id)
        real_g_application_set_application_id(app, effective_id(application_id));
}

void g_set_prgname(const char *prgname) {
    resolve();
    if (real_g_set_prgname) real_g_set_prgname(effective_id(prgname));
}

const char *g_get_prgname(void) {
    resolve();
    init_override_id();
    if (override_id && *override_id) return override_id;
    return real_g_get_prgname ? real_g_get_prgname() : NULL;
}

__attribute__((constructor))
static void gtk_class_fix_ctor(void) {
    resolve();
    init_override_id();
    if (override_id && real_g_set_prgname) real_g_set_prgname(override_id);
}
