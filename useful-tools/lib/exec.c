/* Modified version of
 * https://github.com/darealshinji/linuxdeploy-plugin-checkrt/blob/master/exec.c
 * Unsets known variables that cause issues rather than restoring to parent enviroment
 * One issue with restoring to the parent enviroment is that it unset variables set by
 * terminal emulators like TERM which need to be preserved in the child shell
 *
 * This library also fixes a common issue when appimage portable home, config, etc
 * mode is used, where for example the HOME var from the portable .home dir would
 * be inherited by other processes launched by the appimage in portable mode
 * causing them to start using the fake .home dir instead of the real home
*/

#ifndef _GNU_SOURCE
#define _GNU_SOURCE
#endif
#include <dlfcn.h>
#include <stdio.h>
#include <stdlib.h>
#include <string.h>
#include <sys/param.h>
#include <sys/types.h>
#include <unistd.h>
#include <fcntl.h>

typedef int (*execve_func_t)(const char *filename, char *const argv[], char *const envp[]);

#define VISIBLE __attribute__ ((visibility ("default")))

#if !defined(DEBUG) && (defined(EXEC_TEST) || defined(ENV_TEST))
#define DEBUG 1
#endif

#ifdef DEBUG
#include <errno.h>
#define DEBUG_PRINT(...) \
    if (getenv("APPIMAGE_EXEC_DEBUG")) { \
        printf("APPIMAGE_EXEC>> " __VA_ARGS__); \
    }
#else
#define DEBUG_PRINT(...)  /**/
#endif

// problematic vars to check
static const char* vars_to_unset[] = {
    "BABL_PATH",
    "__EGL_VENDOR_LIBRARY_DIRS",
    "GBM_BACKENDS_PATH",
    "GCONV_PATH",
    "GDK_PIXBUF_MODULEDIR",
    "GDK_PIXBUF_MODULE_FILE",
    "GEGL_PATH",
    "GIO_MODULE_DIR",
    "GI_TYPELIB_PATH",
    "GSETTINGS_SCHEMA_DIR",
    "GST_PLUGIN_PATH",
    "GST_PLUGIN_SCANNER",
    "GST_PLUGIN_SYSTEM_PATH",
    "GST_PLUGIN_SYSTEM_PATH_1_0",
    "GTK_DATA_PREFIX",
    "GTK_EXE_PREFIX",
    "GTK_IM_MODULE_FILE",
    "GTK_PATH",
    "LD_LIBRARY_PATH",
    "LD_PRELOAD",
    "LIBDECOR_PLUGIN_DIR",
    "LIBGL_DRIVERS_PATH",
    "LIBVA_DRIVERS_PATH",
    "PERLLIB",
    "PIPEWIRE_MODULE_DIR",
    "PYTHONHOME",
    "QT_PLUGIN_PATH",
    "SPA_PLUGIN_DIR",
    "TCL_LIBRARY",
    "TK_LIBRARY",
    "XKB_CONFIG_ROOT",
    "XTABLES_LIBDIR",
    NULL
};

static char* const* create_cleaned_env(char* const* original_env)
{
    const char *appdir = getenv("APPDIR");
    if (!appdir) {
        return original_env;
    }

    size_t env_count = 0;
    while (original_env[env_count] != NULL) {
        env_count++;
    }

    char** new_env = calloc(env_count + 1, sizeof(char*));
    size_t new_env_index = 0;

    for (size_t i = 0; i < env_count; i++) {
        int should_copy = 1;

        // check if this is a variable we should potentially unset
        for (const char** var = vars_to_unset; *var != NULL; var++) {
            size_t var_len = strlen(*var);
            if (strncmp(original_env[i], *var, var_len) == 0 &&
                original_env[i][var_len] == '=') {

                const char* value = original_env[i] + var_len + 1;

                // unset if the value contains APPDIR
                if (strstr(value, appdir) != NULL) {
                    should_copy = 0;
                    DEBUG_PRINT("Unset env var %s (points to APPDIR)\n", *var);
                    break;
                }
            }
        }

        if (should_copy) {
            new_env[new_env_index] = strdup(original_env[i]);
            new_env_index++;
        }
    }

    new_env[new_env_index] = NULL;

    return new_env;
}

static void env_free(char* const *env)
{
    if (!env) return;

    for (size_t i = 0; env[i] != NULL; i++) {
        free(env[i]);
    }
    free((char**)env);
}

static int is_external_process(const char *filename)
{
    const char *appdir = getenv("APPDIR");
    if (!appdir)
        return 0;
    DEBUG_PRINT("APPDIR = %s\n", appdir);

    return strncmp(filename, appdir, MIN(strlen(filename), strlen(appdir))) != 0;
}

static int exec_common(execve_func_t function, const char *filename, char* const argv[], char* const envp[])
{
    char *fullpath = canonicalize_file_name(filename);
    DEBUG_PRINT("filename %s, fullpath %s\n", filename, fullpath ? fullpath : "(null)");

    // Restore portable dirs values
    const char *real_data = getenv("REAL_XDG_DATA_HOME");
    if (real_data && *real_data) {
        if (setenv("XDG_DATA_HOME", real_data, 1) == 0) {
            DEBUG_PRINT("Restored XDG_DATA_HOME: %s\n", real_data);
        } else {
            DEBUG_PRINT("Failed to restore XDG_DATA_HOME (wanted '%s')\n", real_data);
        }
    }

    const char *real_config = getenv("REAL_XDG_CONFIG_HOME");
    if (real_config && *real_config) {
        if (setenv("XDG_CONFIG_HOME", real_config, 1) == 0) {
            DEBUG_PRINT("Restored XDG_CONFIG_HOME: %s\n", real_config);
        } else {
            DEBUG_PRINT("Failed to restore XDG_CONFIG_HOME (wanted '%s')\n", real_config);
        }
    }

    const char *real_cache = getenv("REAL_XDG_CACHE_HOME");
    if (real_cache && *real_cache) {
        if (setenv("XDG_CACHE_HOME", real_cache, 1) == 0) {
            DEBUG_PRINT("Restored XDG_CACHE_HOME: %s\n", real_cache);
        } else {
            DEBUG_PRINT("Failed to restore XDG_CACHE_HOME (wanted '%s')\n", real_cache);
        }
    }

    const char *real_home = getenv("REAL_HOME");
    if (real_home && *real_home) {
        if (setenv("HOME", real_home, 1) == 0) {
            DEBUG_PRINT("Restored HOME: %s\n", real_home);
        } else {
            DEBUG_PRINT("Failed to restore HOME (wanted '%s')\n", real_home);
        }
    }

    // remove problematic variables
    char* const *env = envp;
    const char* path_to_check = fullpath ? fullpath : filename;
    if (is_external_process(path_to_check)) {
        DEBUG_PRINT("External process detected. Cleaning environment variables\n");
        env = create_cleaned_env(envp);
        if (!env) {
            env = envp;
            DEBUG_PRINT("Error creating cleaned environment\n");
        }
    }

    // Change working directory to ORIGINAL_WORKING_DIR if set
    const char* original_working_dir = getenv("ORIGINAL_WORKING_DIR");
    if (original_working_dir) {
        if (chdir(original_working_dir) == 0) {
            DEBUG_PRINT("Changed working directory to ORIGINAL_WORKING_DIR: %s\n", original_working_dir);
            unsetenv("ORIGINAL_WORKING_DIR");
        } else {
            DEBUG_PRINT("Failed to change working directory to: %s\n", original_working_dir);
        }
    }

    int ret = function(filename, argv, env);

    if (fullpath != filename)
        free(fullpath);

    if (env != envp)
        env_free(env);

    return ret;
}

VISIBLE int execve(const char *filename, char *const argv[], char *const envp[])
{
    DEBUG_PRINT("execve call hijacked: %s\n", filename);
    execve_func_t execve_orig = dlsym(RTLD_NEXT, "execve");
    if (!execve_orig) {
        DEBUG_PRINT("Error getting execve original symbol: %s\n", strerror(errno));
    }
    return exec_common(execve_orig, filename, argv, envp);
}

VISIBLE int execv(const char *filename, char *const argv[]) {
    DEBUG_PRINT("execv call hijacked: %s\n", filename);
    return execve(filename, argv, environ);
}

VISIBLE int execvpe(const char *filename, char *const argv[], char *const envp[])
{
    DEBUG_PRINT("execvpe call hijacked: %s\n", filename);
    execve_func_t execvpe_orig = dlsym(RTLD_NEXT, "execvpe");
    if (!execvpe_orig) {
        DEBUG_PRINT("Error getting execvpe original symbol: %s\n", strerror(errno));
    }
    return exec_common(execvpe_orig, filename, argv, envp);
}

VISIBLE int execvp(const char *filename, char *const argv[]) {
    DEBUG_PRINT("execvp call hijacked: %s\n", filename);
    return execvpe(filename, argv, environ);
}

#ifdef EXEC_TEST
int main(int argc, char *argv[]) {
    putenv("APPIMAGE_EXEC_DEBUG=1");
    puts("EXEC TEST");
    execv("/bin/true", argv);
    return 0;
}
#elif defined(ENV_TEST)
int main() {
    putenv("APPIMAGE_EXEC_DEBUG=1");
    puts("ENV TEST");
    char* const* test_env = create_cleaned_env(environ);
    env_free(test_env);
    return 0;
}
#endif
