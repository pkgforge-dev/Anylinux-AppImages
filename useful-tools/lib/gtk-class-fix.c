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
#include <stdlib.h>
#include <string.h>
#include <stdio.h>
#include <stdarg.h>
#include <glib.h>
#include <gio/gio.h>
#include <gobject/gobject.h>

static const char *override_id = NULL;
static int override_checked = 0;
static int in_override = 0;

typedef GApplication *(*fp_g_application_new)(const char *, GApplicationFlags);
typedef GApplication *(*fp_gtk_application_new)(const char *, GApplicationFlags);
typedef void (*fp_g_application_set_application_id)(GApplication *, const char *);
typedef void (*fp_g_set_prgname)(const char *);
typedef const char *(*fp_g_get_prgname)(void);
typedef gpointer (*fp_g_object_new)(GType, const gchar *, ...);
typedef GObject *(*fp_g_object_new_valist)(GType, const gchar *, va_list);
typedef GObject *(*fp_g_object_new_with_properties)(GType, guint, const gchar **, const GValue *);

static fp_g_application_new                real_g_application_new                = NULL;
static fp_gtk_application_new              real_gtk_application_new              = NULL;
static fp_g_application_set_application_id real_g_application_set_application_id = NULL;
static fp_g_set_prgname                    real_g_set_prgname                    = NULL;
static fp_g_get_prgname                    real_g_get_prgname                    = NULL;
static fp_g_object_new                     real_g_object_new                     = NULL;
static fp_g_object_new_valist              real_g_object_new_valist              = NULL;
static fp_g_object_new_with_properties     real_g_object_new_with_properties     = NULL;

static void init_override_id(void) {
    if (override_checked) { return; }
    override_checked = 1;

    /* Get the class */
    const char *env = getenv("GTK_WINDOW_CLASS");
    if (env && *env) {
        override_id = env;
        fprintf(stderr, " [gtk-class-fix.so] Setting window class to '%s'\n", override_id);
    }
}

static const char *effective_id(const char *requested) {
    init_override_id();
    /* If override_id is set and not empty, use it; otherwise use requested */
    if (override_id && *override_id) { return override_id; }
    return requested;
}

static void resolve(void) {
    /* Only look up each function once (if not already found) */
    if (! real_g_application_new) {
        real_g_application_new = (fp_g_application_new)
            dlsym(RTLD_NEXT, "g_application_new");
    }
    if (!real_gtk_application_new) {
        real_gtk_application_new = (fp_gtk_application_new)
            dlsym(RTLD_NEXT, "gtk_application_new");
    }
    if (!real_g_application_set_application_id) {
        real_g_application_set_application_id = (fp_g_application_set_application_id)
            dlsym(RTLD_NEXT, "g_application_set_application_id");
    }
    if (!real_g_set_prgname) {
        real_g_set_prgname = (fp_g_set_prgname)
            dlsym(RTLD_NEXT, "g_set_prgname");
    }
    if (!real_g_get_prgname) {
        real_g_get_prgname = (fp_g_get_prgname)
            dlsym(RTLD_NEXT, "g_get_prgname");
    }
    if (!real_g_object_new) {
        real_g_object_new = (fp_g_object_new)
            dlsym(RTLD_NEXT, "g_object_new");
    }
    if (!real_g_object_new_valist) {
        real_g_object_new_valist = (fp_g_object_new_valist)
            dlsym(RTLD_NEXT, "g_object_new_valist");
    }
    if (! real_g_object_new_with_properties) {
        real_g_object_new_with_properties = (fp_g_object_new_with_properties)
            dlsym(RTLD_NEXT, "g_object_new_with_properties");
    }
}

static void maybe_override(GObject *obj) {
    /* Sanity checks */
    if (!obj) { return; }
    if (in_override) { return; }

    init_override_id();

    if (!override_id || !*override_id) { return; }

    /* Is this a GApplication?  If not, skip it */
    if (!G_IS_APPLICATION(obj)) { return; }
    GApplication *app = G_APPLICATION(obj);

    /* Get current ID and check if it's already what we want */
    const char *current_id = g_application_get_application_id(app);
    if (current_id && strcmp(current_id, override_id) == 0) {
        return;  /* Already set correctly */
    }

    /* Prevent recursion */
    in_override = 1;

    /* Apply the override */
    if (real_g_application_set_application_id) {
        real_g_application_set_application_id(app, override_id);
    }
    if (real_g_set_prgname) {
        real_g_set_prgname(override_id);
    }

    /* Clear the flag */
    in_override = 0;
}

GApplication *g_application_new(const char *application_id, GApplicationFlags flags) {
    resolve();

    /* Call real function with possibly-modified ID */
    GApplication *app = NULL;
    if (real_g_application_new) {
        app = real_g_application_new(effective_id(application_id), flags);
    }

    /* Ensure override is applied */
    maybe_override(G_OBJECT(app));

    return app;
}

GApplication *gtk_application_new(const char *application_id, GApplicationFlags flags) {
    resolve();

    GApplication *app = NULL;
    if (real_gtk_application_new) {
        app = real_gtk_application_new(effective_id(application_id), flags);
    }

    maybe_override(G_OBJECT(app));

    return app;
}

void g_application_set_application_id(GApplication *app, const char *application_id) {
    resolve();

    if (real_g_application_set_application_id) {
        real_g_application_set_application_id(app, effective_id(application_id));
    }
}

void g_set_prgname(const char *prgname) {
    resolve();

    if (real_g_set_prgname) {
        real_g_set_prgname(effective_id(prgname));
    }
}

const char *g_get_prgname(void) {
    resolve();
    init_override_id();

    /* If override is set, return it */
    if (override_id && *override_id) {
        return override_id;
    }

    /* Otherwise, return what the real function returns */
    if (real_g_get_prgname) {
        return real_g_get_prgname();
    }

    return NULL;
}

gpointer g_object_new(GType type, const gchar *first_property_name, ...) {
    resolve();

    GObject *obj = NULL;

    if (real_g_object_new_valist) {
        /* Set up to handle variable arguments */
        va_list ap;
        va_start(ap, first_property_name);  /* Start reading args after first_property_name */
        obj = real_g_object_new_valist(type, first_property_name, ap);
        va_end(ap);
    } else if (real_g_object_new) {
        /* Fallback:  call with just the first property */
        obj = (GObject*)real_g_object_new(type, first_property_name);
    }

    /* Check if this created a GApplication and override if needed */
    maybe_override(obj);

    return obj;
}

GObject *g_object_new_valist(GType type, const gchar *first_property_name, va_list var_args) {
    resolve();

    GObject *obj = NULL;
    if (real_g_object_new_valist) {
        obj = real_g_object_new_valist(type, first_property_name, var_args);
    }

    maybe_override(obj);

    return obj;
}

GObject *g_object_new_with_properties(
    GType type,
    guint n_properties,
    const gchar **names,
    const GValue *values
) {
    resolve();

    GObject *obj = NULL;
    if (real_g_object_new_with_properties) {
        obj = real_g_object_new_with_properties(type, n_properties, names, values);
    }

    maybe_override(obj);

    return obj;
}

__attribute__((constructor))
static void gtk_class_fix_ctor(void) {
    resolve();
    init_override_id();
    /* If we have an override, set the program name immediately */
    if (override_id && real_g_set_prgname) {
        real_g_set_prgname(override_id);
    }
}
