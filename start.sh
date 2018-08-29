#!/usr/bin/env bash
set -ex

GROUP=staff
USER_UID=1001

if [ "$(id -u "$USER" 2>/dev/null)" != $USER_UID ]; then
    useradd -g $GROUP -u $USER_UID -d /home/$USER $USER
fi

# this is only for running locally - in-cluster, home directories are
# provided via NAS
echo "${USER}:${USER}" | chpasswd
if [ ! -d /home/$USER ]; then
    mkdir -p /home/$USER
fi
chown "${USER}:${GROUP}" /home/$USER
export HOME=/home/$USER

# Pass select root env vars to user's R environment
echo "AWS_DEFAULT_REGION=${AWS_DEFAULT_REGION}" >> /etc/R/Renviron

# set secure cookie key
set +x
echo -n "${SECURE_COOKIE_KEY}" > /var/lib/rstudio-server/secure-cookie-key
set -x
chmod 600 /var/lib/rstudio-server/secure-cookie-key

# Use Debian's /usr/bin/editor (configured with update-alternatives --set editor)
unset EDITOR

/usr/lib/rstudio-server/bin/rserver --server-daemonize=0
