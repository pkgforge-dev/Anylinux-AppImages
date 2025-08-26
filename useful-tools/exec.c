/* Modified version of
 * https://github.com/darealshinji/linuxdeploy-plugin-checkrt/blob/master/exec.c
 * Unsets known variables that cause issues rather than restoring to parent enviroment
 * One issue with restoring to the parent enviroment is that it unset variables set by
 * terminal emulators like TERM which need to be preserved in the child shell
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
#include <pwd.h>
#include <fcntl.h>

typedef int (*execve_func_t)(const char *filename, char *const argv[], char *const envp[]);

// Original environment values before AppImage portable home/config
static char *original_home = NULL;
static char *original_xdg_config_home = NULL;
static char *original_xdg_data_home = NULL;
// Track whether parent actually had XDG variables set (vs being unset)
static int parent_had_xdg_config_home = 0;
static int parent_had_xdg_data_home = 0;
static int env_initialized = 0;

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

// Read environment variable from parent process via /proc/[ppid]/environ
static char* read_parent_env(const char* var_name) {
    pid_t ppid = getppid();
    if (ppid <= 1) return NULL;
    
    char proc_path[256];
    snprintf(proc_path, sizeof(proc_path), "/proc/%d/environ", ppid);
    
    int fd = open(proc_path, O_RDONLY);
    if (fd < 0) return NULL;
    
    char buffer[8192];
    ssize_t bytes_read = read(fd, buffer, sizeof(buffer) - 1);
    close(fd);
    
    if (bytes_read <= 0) return NULL;
    buffer[bytes_read] = '\0';
    
    size_t var_len = strlen(var_name);
    char *pos = buffer;
    char *end = buffer + bytes_read;
    
    while (pos < end) {
        if (strncmp(pos, var_name, var_len) == 0 && pos[var_len] == '=') {
            char *value_start = pos + var_len + 1;
            char *value_end = value_start;
            while (value_end < end && *value_end != '\0') {
                value_end++;
            }
            size_t value_len = value_end - value_start;
            char *result = malloc(value_len + 1);
            if (result) {
                memcpy(result, value_start, value_len);
                result[value_len] = '\0';
                return result;
            }
            return NULL;
        }
        // Move to next environment variable
        while (pos < end && *pos != '\0') pos++;
        pos++; // Skip the null terminator
    }
    
    return NULL;
}

// Get the real home directory from passwd
static char* get_real_home_from_passwd() {
    struct passwd *pw = getpwuid(getuid());
    if (pw && pw->pw_dir) {
        return strdup(pw->pw_dir);
    }
    return NULL;
}

// Detect if portable home/config is in use
static int is_portable_home_in_use() {
    const char *current_home = getenv("HOME");
    if (!current_home) return 0;
    
    // Check if HOME contains .home suffix (portable home pattern)
    // This indicates HOME = $APPIMAGE.home where APPIMAGE is the full path to AppImage file
    size_t home_len = strlen(current_home);
    if (home_len > 5 && strcmp(current_home + home_len - 5, ".home") == 0) {
        return 1;
    }
    
    return 0;
}

// Check if XDG_CONFIG_HOME is a portable AppImage config directory ($APPIMAGE.config)
static int is_portable_xdg_config() {
    const char *xdg_config = getenv("XDG_CONFIG_HOME");
    const char *appimage = getenv("APPIMAGE");
    
    if (!xdg_config || !appimage) return 0;
    
    // Build expected portable config path: $APPIMAGE.config
    size_t appimage_len = strlen(appimage);
    size_t expected_len = appimage_len + 7; // ".config"
    char *expected_path = malloc(expected_len + 1);
    if (!expected_path) return 0;
    
    snprintf(expected_path, expected_len + 1, "%s.config", appimage);
    int is_portable = (strcmp(xdg_config, expected_path) == 0);
    free(expected_path);
    
    return is_portable;
}

// Check if XDG_DATA_HOME is a portable AppImage data directory ($APPIMAGE.share)
static int is_portable_xdg_data() {
    const char *xdg_data = getenv("XDG_DATA_HOME");
    const char *appimage = getenv("APPIMAGE");
    
    if (!xdg_data || !appimage) return 0;
    
    // Build expected portable data path: $APPIMAGE.share
    size_t appimage_len = strlen(appimage);
    size_t expected_len = appimage_len + 6; // ".share"
    char *expected_path = malloc(expected_len + 1);
    if (!expected_path) return 0;
    
    snprintf(expected_path, expected_len + 1, "%s.share", appimage);
    int is_portable = (strcmp(xdg_data, expected_path) == 0);
    free(expected_path);
    
    return is_portable;
}

// Detect if any portable AppImage directories are in use
static int is_portable_appimage_in_use() {
    // Check HOME for .home suffix
    if (is_portable_home_in_use()) {
        return 1;
    }
    
    // Check XDG_CONFIG_HOME for portable pattern ($APPIMAGE.config)
    if (is_portable_xdg_config()) {
        return 1;
    }
    
    // Check XDG_DATA_HOME for portable pattern ($APPIMAGE.share)
    if (is_portable_xdg_data()) {
        return 1;
    }
    
    return 0;
}

// Get original environment values using three-tiered approach
static void get_original_env_values() {
    if (env_initialized) return;
    
    // First tier: try to read from parent process
    original_home = read_parent_env("HOME");
    original_xdg_config_home = read_parent_env("XDG_CONFIG_HOME");
    original_xdg_data_home = read_parent_env("XDG_DATA_HOME");
    
    // Track whether parent actually had these variables set
    parent_had_xdg_config_home = (original_xdg_config_home != NULL);
    parent_had_xdg_data_home = (original_xdg_data_home != NULL);
    
    // Second tier: if HOME not found from parent, try passwd
    if (!original_home) {
        original_home = get_real_home_from_passwd();
    }
    
    // Note: We do NOT calculate XDG defaults if parent didn't have them set
    // Applications will use ~/.config and ~/.local/share defaults when these are unset
    
    env_initialized = 1;
    
    DEBUG_PRINT("Original environment values: HOME=%s, XDG_CONFIG_HOME=%s (parent_had=%d), XDG_DATA_HOME=%s (parent_had=%d)\n",
                original_home ? original_home : "(null)",
                original_xdg_config_home ? original_xdg_config_home : "(null)", parent_had_xdg_config_home,
                original_xdg_data_home ? original_xdg_data_home : "(null)", parent_had_xdg_data_home);
}

// Library constructor to initialize original environment values
__attribute__((constructor))
static void init_original_env() {
    // Always try to capture original values when we have APPDIR set
    // This allows us to restore them later if needed
    const char *appdir = getenv("APPDIR");
    if (appdir) {
        get_original_env_values();
        DEBUG_PRINT("Initialized with APPDIR=%s\n", appdir);
    }
}

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
    
    // Initialize environment values if not already done and we have APPDIR
    if (!env_initialized) {
        get_original_env_values();
    }

    size_t env_count = 0;
    while (original_env[env_count] != NULL) {
        env_count++;
    }

    // Reserve extra space for potential HOME, XDG_CONFIG_HOME, XDG_DATA_HOME additions
    char** new_env = calloc(env_count + 4, sizeof(char*));
    size_t new_env_index = 0;
    
    // Track if we've seen and need to replace HOME, XDG_CONFIG_HOME, XDG_DATA_HOME
    int found_home = 0, found_xdg_config = 0, found_xdg_data = 0;
    
    // Only restore portable home paths if we have captured original values and portable AppImage is in use
    int should_restore_home = (env_initialized && is_portable_appimage_in_use());

    for (size_t i = 0; i < env_count; i++) {
        int should_copy = 1;
        int is_home_related = 0;

        // Check for HOME, XDG_CONFIG_HOME, XDG_DATA_HOME that need restoration
        if (should_restore_home) {
            if (strncmp(original_env[i], "HOME=", 5) == 0) {
                if (original_home) {
                    size_t new_len = strlen("HOME=") + strlen(original_home) + 1;
                    char *new_home_var = malloc(new_len);
                    if (new_home_var) {
                        snprintf(new_home_var, new_len, "HOME=%s", original_home);
                        new_env[new_env_index++] = new_home_var;
                        DEBUG_PRINT("Restored HOME to: %s\n", original_home);
                    }
                    found_home = 1;
                    is_home_related = 1;
                }
            } else if (strncmp(original_env[i], "XDG_CONFIG_HOME=", 16) == 0) {
                // Check if this is a portable config dir ($APPIMAGE.config)
                int is_portable_config = is_portable_xdg_config();
                
                if (parent_had_xdg_config_home && original_xdg_config_home) {
                    // Parent had it set, restore to original value
                    size_t new_len = strlen("XDG_CONFIG_HOME=") + strlen(original_xdg_config_home) + 1;
                    char *new_var = malloc(new_len);
                    if (new_var) {
                        snprintf(new_var, new_len, "XDG_CONFIG_HOME=%s", original_xdg_config_home);
                        new_env[new_env_index++] = new_var;
                        DEBUG_PRINT("Restored XDG_CONFIG_HOME to: %s\n", original_xdg_config_home);
                    }
                    found_xdg_config = 1;
                    is_home_related = 1;
                } else if (!parent_had_xdg_config_home && is_portable_config) {
                    // Parent didn't have it set and current is portable variant - unset it
                    DEBUG_PRINT("Unsetting portable XDG_CONFIG_HOME (parent didn't have it set)\n");
                    found_xdg_config = 1;
                    is_home_related = 1;
                    // Don't add anything - effectively unsetting the variable
                }
            } else if (strncmp(original_env[i], "XDG_DATA_HOME=", 14) == 0) {
                // Check if this is a portable data dir ($APPIMAGE.share)
                int is_portable_data = is_portable_xdg_data();
                
                if (parent_had_xdg_data_home && original_xdg_data_home) {
                    // Parent had it set, restore to original value
                    size_t new_len = strlen("XDG_DATA_HOME=") + strlen(original_xdg_data_home) + 1;
                    char *new_var = malloc(new_len);
                    if (new_var) {
                        snprintf(new_var, new_len, "XDG_DATA_HOME=%s", original_xdg_data_home);
                        new_env[new_env_index++] = new_var;
                        DEBUG_PRINT("Restored XDG_DATA_HOME to: %s\n", original_xdg_data_home);
                    }
                    found_xdg_data = 1;
                    is_home_related = 1;
                } else if (!parent_had_xdg_data_home && is_portable_data) {
                    // Parent didn't have it set and current is portable variant - unset it
                    DEBUG_PRINT("Unsetting portable XDG_DATA_HOME (parent didn't have it set)\n");
                    found_xdg_data = 1;
                    is_home_related = 1;
                    // Don't add anything - effectively unsetting the variable
                }
            }
        }

        // Skip the home-related variable if we've already handled it
        if (is_home_related) {
            continue;
        }

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
    
    // Add missing HOME, XDG_CONFIG_HOME, XDG_DATA_HOME if they weren't in the original env
    // but only if parent actually had them set (for XDG variables)
    if (should_restore_home) {
        if (!found_home && original_home) {
            size_t new_len = strlen("HOME=") + strlen(original_home) + 1;
            char *new_home_var = malloc(new_len);
            if (new_home_var) {
                snprintf(new_home_var, new_len, "HOME=%s", original_home);
                new_env[new_env_index++] = new_home_var;
                DEBUG_PRINT("Added missing HOME: %s\n", original_home);
            }
        }
        // Only add XDG variables if parent actually had them set
        if (!found_xdg_config && parent_had_xdg_config_home && original_xdg_config_home) {
            size_t new_len = strlen("XDG_CONFIG_HOME=") + strlen(original_xdg_config_home) + 1;
            char *new_var = malloc(new_len);
            if (new_var) {
                snprintf(new_var, new_len, "XDG_CONFIG_HOME=%s", original_xdg_config_home);
                new_env[new_env_index++] = new_var;
                DEBUG_PRINT("Added missing XDG_CONFIG_HOME: %s\n", original_xdg_config_home);
            }
        }
        if (!found_xdg_data && parent_had_xdg_data_home && original_xdg_data_home) {
            size_t new_len = strlen("XDG_DATA_HOME=") + strlen(original_xdg_data_home) + 1;
            char *new_var = malloc(new_len);
            if (new_var) {
                snprintf(new_var, new_len, "XDG_DATA_HOME=%s", original_xdg_data_home);
                new_env[new_env_index++] = new_var;
                DEBUG_PRINT("Added missing XDG_DATA_HOME: %s\n", original_xdg_data_home);
            }
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
