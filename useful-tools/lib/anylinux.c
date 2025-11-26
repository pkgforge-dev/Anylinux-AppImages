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
 *
 * It also sets LC_ALL=C if it detects the application will fail to switch locale
 * While we normally bundle locales with quick-sharun and apps have working
 * language interface, we do not bundle the libc locale because glibc
 * has issues when LOCPATH is used This means some applications like dolphin-emu
 * crash when glibc cannot switch locale even though the application itself can
 * This library checks that and forces the C locale instead to prevent crashes
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
#include <errno.h>
#include <locale.h>

typedef int (*execve_func_t)(const char *filename, char *const argv[], char *const envp[]);

#define LOG(fmt, ...) fprintf(stderr, " [anylinux.so] LOCALEFIX >> " fmt "\n", ##__VA_ARGS__)

__attribute__((constructor))
static void locale_fix_init(void) {
	if (! setlocale(LC_ALL, "")) {
		LOG("Failed to set locale, falling back to bundled C.UTF-8 locale");
		// Check if bundled C.UTF-8 locale is available
		const char *appdir = getenv("APPDIR");
		if (appdir) {
			char locale_path[PATH_MAX];
			snprintf(locale_path, sizeof(locale_path), "%s/lib/locale/C.utf8", appdir);

			if (access(locale_path, F_OK) == 0) {
				LOG("Found bundled C.UTF-8 locale: %s", locale_path);
				// Set LOCPATH to the bundled locales directory
				char locpath[PATH_MAX];
				snprintf(locpath, sizeof(locpath), "%s/lib/locale", appdir);
				if (setenv("LOCPATH", locpath, 1) == 0) {
					LOG("Set LOCPATH to %s", locpath);
				} else {
					LOG("Failed to setenv(LOCPATH, \"%s\"): %s", locpath, strerror(errno));
				}

				// Set LC_ALL to C.UTF-8
				LOG("Setting LC_ALL to C.UTF-8");
				if (setenv("LC_ALL", "C.UTF-8", 1) == 0) {
					if (! setlocale(LC_ALL, "")) {
						LOG("Failed to set locale with C.UTF-8, falling back to bare C locale.");
						if (! setlocale(LC_ALL, "C")) {
							LOG("Failed to setlocale(LC_ALL, \"C\"): %s", strerror(errno));
						}
						if (setenv("LC_ALL", "C", 1) != 0) {
							LOG("Failed to setenv(LC_ALL, \"C\"): %s", strerror(errno));
						}
					}
				} else {
					LOG("Failed to setenv(LC_ALL, \"C.UTF-8\"): %s", strerror(errno));
					if (!setlocale(LC_ALL, "C")) {
						LOG("Failed to setlocale(LC_ALL, \"C\"): %s", strerror(errno));
					}
					if (setenv("LC_ALL", "C", 1) != 0) {
						LOG("Failed to setenv(LC_ALL, \"C\"): %s", strerror(errno));
					}
				}
			} else {
				LOG("Bundled C.UTF-8 locale not found at %s, falling back to C locale.", locale_path);
				if (!setlocale(LC_ALL, "C")) {
					LOG("Failed to setlocale(LC_ALL, \"C\"): %s", strerror(errno));
				}
				if (setenv("LC_ALL", "C", 1) != 0) {
					LOG("Failed to setenv(LC_ALL, \"C\"): %s", strerror(errno));
				}
			}
		} else {
			LOG("APPDIR not set, cannot check for bundled locales.  Falling back to C locale.");
			if (!setlocale(LC_ALL, "C")) {
				LOG("Failed to setlocale(LC_ALL, \"C\"): %s", strerror(errno));
			}
			if (setenv("LC_ALL", "C", 1) != 0) {
				LOG("Failed to setenv(LC_ALL, \"C\"): %s", strerror(errno));
			}
		}
	}
}

#define VISIBLE __attribute__ ((visibility ("default")))

// print to stderr when APPIMAGE_EXEC_DEBUG=1
static int appimage_exec_debug_enabled(void) {
	const char *v = getenv("ANYLINUX_LIB_DEBUG");
	return v && strcmp(v, "1") == 0;
}

#define DEBUG_PRINT(...) do \
	if (appimage_exec_debug_enabled()) \
		fprintf(stderr, " [anylinux.so] >> " __VA_ARGS__); \
	while (0)

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
	"JACK_DRIVER_DIR",
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

static char* const* create_cleaned_env(char* const* original_env) {
	const char *appdir = getenv("APPDIR");
	if (!appdir) {
		DEBUG_PRINT("APPDIR is NOT set!\n");
		return original_env;
	}
	DEBUG_PRINT("APPDIR is set: %s\n", appdir);

	size_t env_count = 0;
	while (original_env[env_count] != NULL)
		env_count++;

	char** new_env = calloc(env_count + 1, sizeof(char*));
	size_t new_env_index = 0;

	for (size_t i = 0; i < env_count; i++) {
		int should_copy = 1;
		// check if this is a variable we should potentially unset
		for (const char** var = vars_to_unset; *var != NULL; var++) {
			size_t var_len = strlen(*var);
			if (strncmp(original_env[i], *var, var_len) == 0 && original_env[i][var_len] == '=') {
				const char* value = original_env[i] + var_len + 1;
				// unset if the value contains APPDIR
				if (strstr(value, appdir) != NULL) {
					DEBUG_PRINT("Unset %s (value: %s)\n", *var, value);
					should_copy = 0;
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
	DEBUG_PRINT("Child environment has %zu variables (Parent %zu)\n", new_env_index, env_count);
	return new_env;
}

static void env_free(char* const *env) {
	if (!env) return;
	for (size_t i = 0; env[i] != NULL; i++)
		free(env[i]);
	free((char**)env);
}

static int is_external_process(const char *filename) {
	const char *appdir = getenv("APPDIR");
	if (!appdir) {
		DEBUG_PRINT("APPDIR not set; treating %s as internal process\n", filename);
		return 0;
	}

	int external = (strncmp(filename, appdir, MIN(strlen(filename), strlen(appdir))) != 0);
	DEBUG_PRINT("Process '%s' is %s (APPDIR=%s)\n", filename, external ? "EXTERNAL" : "INTERNAL", appdir);
	return external;
}

static int exec_common(execve_func_t function, const char *filename, char* const argv[], char* const envp[]) {
	DEBUG_PRINT("Preparing to exec: %s\n", filename);

	char *fullpath = canonicalize_file_name(filename);
	DEBUG_PRINT("canonicalize file: %s -> %s\n", filename, fullpath ? fullpath : "(null)");

	// Restore portable dirs values
	const char *real_data = getenv("REAL_XDG_DATA_HOME");
	if (real_data && *real_data) {
		if (setenv("XDG_DATA_HOME", real_data, 1) == 0)
			DEBUG_PRINT("Restored XDG_DATA_HOME to %s\n", real_data);
		else
			DEBUG_PRINT("Failed to restore XDG_DATA_HOME to %s\n", real_data);
	}

	const char *real_config = getenv("REAL_XDG_CONFIG_HOME");
	if (real_config && *real_config) {
		if (setenv("XDG_CONFIG_HOME", real_config, 1) == 0)
			DEBUG_PRINT("Restored XDG_CONFIG_HOME to %s\n", real_config);
		else
			DEBUG_PRINT("Failed to restore XDG_CONFIG_HOME to %s\n", real_config);
	}

	const char *real_cache = getenv("REAL_XDG_CACHE_HOME");
	if (real_cache && *real_cache) {
		if (setenv("XDG_CACHE_HOME", real_cache, 1) == 0)
			DEBUG_PRINT("Restored XDG_CACHE_HOME to %s\n", real_cache);
		else
			DEBUG_PRINT("Failed to restore XDG_CACHE_HOME to %s\n", real_cache);
	}

	const char *real_home = getenv("REAL_HOME");
	if (real_home && *real_home) {
		if (setenv("HOME", real_home, 1) == 0)
			DEBUG_PRINT("Restored HOME to %s\n", real_home);
		else
			DEBUG_PRINT("Failed to restore HOME to %s\n", real_home);
	}

	// remove problematic variables
	char* const *env = envp;
	const char* path_to_check = fullpath ? fullpath : filename;
	if (is_external_process(path_to_check)) {
		DEBUG_PRINT("External process detected; cleaning environment\n");
		env = create_cleaned_env(envp);
		if (!env) {
			DEBUG_PRINT("Error creating cleaned environment; using original env\n");
			env = envp;
		}
	} else {
		const char *basename = strrchr(filename, '/');
		basename = basename ? basename + 1 : filename;
		if (strcmp(basename, "xdg-open") == 0 || strcmp(basename, "gio-launch-desktop") == 0) {
			DEBUG_PRINT("Internal process detected (%s); cleaning environment anyway since this is needed\n", basename);
			env = create_cleaned_env(envp);
			if (!env) {
				DEBUG_PRINT("Error creating cleaned environment; using original env\n");
				env = envp;
			}
		} else
			DEBUG_PRINT("Internal process; leaving environment unchanged\n");
	}

	DEBUG_PRINT("Calling exec for %s\n", filename);
	int ret = function(filename, argv, env);

	if (ret == -1) DEBUG_PRINT("Underlying exec returned -1, errno=%d (%s)\n", errno, strerror(errno));
	if (fullpath && fullpath != filename) free(fullpath);
	if (env != envp) env_free(env);

	return ret;
}

VISIBLE int execve(const char *filename, char *const argv[], char *const envp[]) {
	DEBUG_PRINT("execve call hijacked: %s\n", filename);
	execve_func_t execve_orig = dlsym(RTLD_NEXT, "execve");
	if (!execve_orig) {
		DEBUG_PRINT("Error getting original execve symbol: %s\n", dlerror());
		errno = ENOSYS;
		return -1;
	}
	return exec_common(execve_orig, filename, argv, envp);
}

VISIBLE int execv(const char *filename, char *const argv[]) {
	DEBUG_PRINT("execv call hijacked: %s\n", filename);
	return execve(filename, argv, environ);
}

VISIBLE int execvpe(const char *filename, char *const argv[], char *const envp[]) {
	DEBUG_PRINT("execvpe hijacked: %s\n", filename);
	execve_func_t execvpe_orig = dlsym(RTLD_NEXT, "execvpe");
	if (!execvpe_orig) {
		DEBUG_PRINT("Error getting original execvpe symbol: %s\n", dlerror());
		errno = ENOSYS;
		return -1;
	}
	return exec_common(execvpe_orig, filename, argv, envp);
}

VISIBLE int execvp(const char *filename, char *const argv[]) {
	DEBUG_PRINT("execvp hijacked: %s\n", filename);
	return execvpe(filename, argv, environ);
}
