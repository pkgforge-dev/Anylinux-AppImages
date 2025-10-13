# fix-ubuntu-nonsense

**Originally from https://github.com/Samueru-sama/fix-ubuntu-nonsense**

Have your application quickly remove ubuntu namespaces restriction using polkit in a user friendly way.

This is a simple POSIX shell script that will do some basic checks before informing the user about the situation using `zenity` or `kdialog`, then uses `pkexec` to run:

```
echo 'kernel.apparmor_restrict_unprivileged_userns = 0' | tee /etc/sysctl.d/20-fix-namespaces.conf
sysctl -w kernel.apparmor_restrict_unprivileged_userns=0
```

Which removes the restriction fully.

If the user decides to NOT disable the restriction, the script will ask if they do not want to see the prompt ever again and make a lockfile so that it never happens again.

# Usage

To use simply download `fix-namespaces.hook` and execute it before starting your application.

The script has several checks to prevent false positives, but if they happen please open an issue and it will be fixed as soon as possible.

# Why

Starting with ubuntu24.04 they decided to limit the usage of namepsaces.

namespaces are a very important feature of the kernel that allows us to make a "fakeroot" where we then bind/remove access to the real root. Essentially this allows us to isolate an application to its own little enviroment.

Before their common usage what was done to isolate applications was using SUID binaries like firejail, this has the downside that if there is an exploit in the binary it can be used for privelege escalation, something that firejail had many issues with.

Today pretty much all applications use namespaces for their own sandboxing or for sandboxing other apps, more importantly it is used by both chrome/firefox and all electron apps for their internal sandbox.

Even if you think what ubuntu is doing here is right in some way, the current restriction is insanely flawed and can be exploited easily, not to mention that any possible exploit would require local access to the machine, **which is already very bad** since at that point any malware can do anything that the regular user of the system can, including deleting all of`HOME` contents or sending them to a random sever.


For more details see:

* https://ubuntu.com/blog/ubuntu-23-10-restricted-unprivileged-user-namespaces

* https://seclists.org/oss-sec/2025/q1/253

* https://github.com/containers/bubblewrap/issues/505#issuecomment-2093203129

* https://github.com/linuxmint/mint22-beta/issues/82#issuecomment-2232827173

* https://github.com/ivan-hc/AM/blob/main/docs/troubleshooting.md#ubuntu-mess

* https://github.com/probonopd/go-appimage/issues/39#issuecomment-2849803316
