#!/usr/bin/env bash
set -e

echo "Configuring NUT (Network UPS Tools)..."

mkdir -p /etc/nut /var/run/nut

# upsd/drivers drop privileges to the "nut" system user (created by the
# nut-server/nut-client debian packages) and chdir into /var/run/nut as
# that user — the directory must be owned by nut:nut, not root:root, or
# upsd fails immediately with "Can't chdir to /run/nut: Permission denied".
chown -R nut:nut /var/run/nut
chmod 750 /var/run/nut
chown -R root:nut /etc/nut

# nut.conf - standalone mode (this container both drives and serves the UPS)
cat > /etc/nut/nut.conf <<EOF
MODE=standalone
EOF

# ups.conf - defines the UPS section for the driver to use.
#
# user = root: the usbhid-ups driver setuid()s to the "nut" system user by
# default before opening the USB device. Linux drops ALL capabilities
# (including CAP_DAC_OVERRIDE, which `privileged: true` grants) across a
# setuid() call unless explicitly preserved — so even in a privileged
# container, the driver ends up as the unprivileged "nut" user trying to
# open a root-owned /dev/bus/usb/*/* node, failing with "insufficient
# permissions on everything". Telling the driver to stay root avoids the
# setuid entirely; upsd (the network-facing daemon) still drops to "nut"
# separately and is unaffected by this setting.
cat > /etc/nut/ups.conf <<EOF
[${NUT_UPS_NAME}]
	driver = ${NUT_UPS_DRIVER}
	port = ${NUT_UPS_PORT}
	desc = "CyberPower UPS"
	user = root
EOF

# upsd.conf - listen on all interfaces so other containers/hosts can query
cat > /etc/nut/upsd.conf <<EOF
LISTEN 0.0.0.0 3493
EOF

# upsd.users - credentials for admin (upscmd/upsrw) and monitor (upsmon) access
{
	echo "[${NUT_ADMIN_USER}]"
	echo "	password = ${NUT_ADMIN_PASSWORD:-$(head -c 16 /dev/urandom | base64 | tr -dc 'a-zA-Z0-9' | head -c 20)}"
	echo "	actions = SET"
	echo "	instcmds = ALL"
	echo ""
	echo "[${NUT_MONITOR_USER}]"
	echo "	password = ${NUT_MONITOR_PASSWORD:-$(head -c 16 /dev/urandom | base64 | tr -dc 'a-zA-Z0-9' | head -c 20)}"
	echo "	upsmon master"
} > /etc/nut/upsd.users

chmod 640 /etc/nut/upsd.users /etc/nut/ups.conf
chown root:nut /etc/nut/upsd.users /etc/nut/ups.conf 2>/dev/null || true

echo "Starting UPS driver (${NUT_UPS_DRIVER}) for ${NUT_UPS_NAME}..."
/lib/nut/${NUT_UPS_DRIVER} -a "${NUT_UPS_NAME}" || echo "Driver start returned non-zero — will retry via upsdrvctl"
/sbin/upsdrvctl start || true

echo "Starting upsd on 0.0.0.0:3493..."
exec /sbin/upsd -D
