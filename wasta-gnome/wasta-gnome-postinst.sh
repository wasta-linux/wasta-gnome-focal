#!/bin/bash

# ==============================================================================
# wasta-gnome-postinst.sh
#
#   This script is automatically run by the postinst configure step on
#       installation of wasta-gnome-*. It can be manually re-run, but
#       is only intended to be run at package installation.
#
#   2020-07-22 ndm: initial script
#
# ==============================================================================

# ------------------------------------------------------------------------------
# Check to ensure running as root
# ------------------------------------------------------------------------------
#   No fancy "double click" here because normal user should never need to run
if [ $(id -u) -ne 0 ]
then
	echo
	echo "You must run this script with sudo." >&2
	echo "Exiting...."
	sleep 5s
	exit 1
fi

# ------------------------------------------------------------------------------
# Initial setup
# ------------------------------------------------------------------------------

echo
echo "*** Script Entry: wasta-gnome-postinst.sh"
echo

# Setup Directory for later reference
DIR=/usr/share/wasta-gnome

# ------------------------------------------------------------------------------
# General initial config
# ------------------------------------------------------------------------------

# Set GDM3 default config.
if [[ -e /etc/gdm3 ]]; then
	# Enable GDM3 debug logs (to capture session names).
	gdm_custom_conf=/etc/gdm3/custom.conf
	if [[ ! -e ${gdm_custom_conf}.orig ]]; then
		mv $gdm_custom_conf{,.orig}
	fi
	cat > $gdm_custom_conf << EOF
[debug]
Enable=true
EOF

	# Add Wasta logo to GDM3 greeter.
	gdm_greeter_conf=/etc/gdm3/greeter.dconf-defaults
	if [[ ! -e ${gdm_greeter_conf}.orig ]]; then
		mv $gdm_greeter_conf{,.orig}
	fi
	#	Ref: https://wiki.debian.org/GDM
	cat > $gdm_greeter_conf << EOF
[org/gnome/login-screen]
logo='/usr/share/plymouth/themes/wasta-logo/wasta-linux.png'
EOF

	# Change GDM3 greeter background color.
	#	Ref: https://github.com/thiggy01/change-gdm-background/blob/master/change-gdm-background
	/usr/share/wasta-gnome/change-gdm3-background.sh '#3C3C3C'

	# Copy wasta-login.sh to GDM3 PostLogin/Default.
	gdm_default=/etc/gdm3/PostLogin/Default
	if [[ -e $gdm_default ]]; then
		# Have to remove already-linked previous version before copying new version.
		rm $gdm_default
	fi
	wasta_login=/usr/share/wasta-multidesktop/scripts/wasta-login.sh
	cp -l "$wasta_login" /etc/gdm3/PostLogin/Default
fi

# Add Wasta icon to slick-greeter desktop entry if slick-greeter is installed.
badges_dir=/usr/share/slick-greeter/badges
wasta_gnome_badge=/usr/share/slick-greeter/badges/wasta-gnome.png
if [[ -d $badges_dir ]] && [[ ! -e $wasta_gnome_badge ]]; then
	cp -l /usr/share/wasta-multidesktop/resources/wl-round-22.png "$wasta_gnome_badge"
fi

# Disable gnome-screensaver by default (re-enabled at wasta-gnome session login).
if [[ -e /usr/share/dbus-1/services/org.gnome.ScreenSaver.service ]]; then
    mv /usr/share/dbus-1/services/org.gnome.ScreenSaver.service{,.disabled}
fi

# ------------------------------------------------------------------------------
# Dconf / Gsettings Default Value adjustments
# ------------------------------------------------------------------------------
echo
echo "*** Updating dconf / gsettings default values"
echo

# Updating dconf before GNOME schemas because they depend on its entries.
dconf update

# GNOME Extension schemas: separate location from System schemas.
glib-compile-schemas /usr/share/gnome-shell/extensions/applications-overview-tooltip@RaphaelRochet/schemas/ > /dev/null 2>&1 || true;

glib-compile-schemas /usr/share/gnome-shell/extensions/dash-to-panel@jderose9.github.com/schemas/ > /dev/null 2>&1 || true;

# gschema is in system location when using deb package, so separate cmd not needed.
#glib-compile-schemas /usr/share/gnome-shell/extensions/desktop-icons@csoriano/schemas/ > /dev/null 2>&1 || true;

glib-compile-schemas /usr/share/gnome-shell/extensions/panel-osd@berend.de.schouwer.gmail.com/schemas/ > /dev/null 2>&1 || true;

# MAIN System schemas: we have placed our override file in this directory
# Sending any "error" to null (if key not found don't want to worry user)
glib-compile-schemas /usr/share/glib-2.0/schemas/ > /dev/null 2>&1 || true;

# ------------------------------------------------------------------------------
# Setting initial Nautilus config
# ------------------------------------------------------------------------------
echo
echo "*** Setting initial Nautilus config"
echo
# filemanager-actions has no system config file, so copy user config to all
#	existing users' .config folders.
users=$(find /home/* -maxdepth 0 -type d | cut -d '/' -f3)
while IFS= read -r user; do
    if [[ $(grep "$user:" /etc/passwd) ]]; then
        mkdir -p -m 755 "/home/$user/.config/filemanager-actions"
        cp /etc/skel/.config/filemanager-actions/filemanager-actions.conf "/home/$user/.config/filemanager-actions/filemanager-actions.conf"
        chown -R $user:$user "/home/$user/.config/filemanager-actions"
        chmod 644 "/home/$user/.config/filemanager-actions/filemanager-actions.conf"
    fi
done <<< "$users"

echo
echo "*** Restarting GNOME Shell"
echo
killall -SIGQUIT gnome-shell

# ------------------------------------------------------------------------------
# Finished
# ------------------------------------------------------------------------------
echo
echo "*** Script Exit: wasta-gnome-postinst.sh"
echo

exit 0
