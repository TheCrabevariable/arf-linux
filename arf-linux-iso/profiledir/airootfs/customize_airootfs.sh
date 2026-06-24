#!/usr/bin/env bash

# Apply settings after all packages are installed.
# This runs inside the chroot during ISO build.

# Mark firstboot as complete so systemd-firstboot doesn't prompt
touch /etc/.firstboot-ran-sentinel


# Remove .pacnew files that may have overwritten our airootfs overlays
find /etc -name '*.pacnew' -delete

# Force empty root password
usermod -p '' root 2>/dev/null || sed -i 's|^root:[^:]*:|root::|' /etc/shadow

# Ensure /etc/hostname
echo "archiso" > /etc/hostname

# Ensure locale
echo "LANG=C.UTF-8" > /etc/locale.conf
