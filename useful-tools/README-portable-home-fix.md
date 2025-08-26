# AppImage Portable Home/Config Fix

This document explains the portable home/config fix implemented in `exec.c`.

## Problem

When AppImage sets portable home/config directories (e.g., `HOME=/path/to/app.home`), child processes launched from the AppImage inherit these fake home paths instead of using the real system home directory. This causes external processes to use the wrong home directory.

## Solution

The fix adds functionality to:

1. **Detect** when portable home/config is in use (HOME ends with `.home` or contains `/tmp/.mount_`)
2. **Store** original values of `HOME`, `XDG_CONFIG_HOME`, and `XDG_DATA_HOME` when the library loads
3. **Restore** these original values when launching external processes  
4. **Maintain** AppImage portable paths for internal processes

## Three-Tiered Approach

The fix uses a three-tiered approach to find original environment values:

1. **First tier**: Read from parent process environment via `/proc/[ppid]/environ`
2. **Second tier**: Calculate standard paths based on real home directory from passwd
3. **Third tier**: Use reasonable defaults if all else fails

## Testing

To test the fix:

```bash
# Compile the library
gcc -shared -fPIC exec.c -o exec.so -ldl

# Test with portable home
APPDIR="/tmp/.mount_test" \
HOME="/tmp/.mount_test.home" \
XDG_CONFIG_HOME="/tmp/.mount_test.home/.config" \
XDG_DATA_HOME="/tmp/.mount_test.home/.local/share" \
LD_PRELOAD="./exec.so" \
/bin/sh -c 'echo "Child HOME=$HOME"'
```

**Expected result**: Child process will show the real system HOME, not the portable one.

## Backward Compatibility

- All existing functionality is preserved
- No changes to existing behavior when portable home is not detected
- ENV_TEST and EXEC_TEST continue to work as before