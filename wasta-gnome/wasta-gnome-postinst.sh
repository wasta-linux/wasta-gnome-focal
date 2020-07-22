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
# Set app-grid icon
# ------------------------------------------------------------------------------
echo
echo "*** Setting Wasta main menu icon"
echo

os_version=$(cat /etc/os-release | grep VERSION_CODENAME | cut -d '=' -f2)
if [[ $os_version == 'bionic' ]]; then
    default_theme=Adwaita
elif [[ $os_version == 'focal' ]]; then
    default_theme=Yaru
else
    # OS not supported.
    echo "Unknown version '$os_version'. Not setting main menu icon."
fi
new_icon=/usr/share/icons/hicolor/scalable/emblems/wasta-linux-main-menu.svg
old_icon=/usr/share/icons/$default_theme/scalable/actions/view-app-grid-symbolic.svg
# Backup original icon if not already backed up.
if [[ ! -e $old_icon.orig ]]; then
    cp $old_icon{,.orig}
fi
# Copy new icon to original icon location and name.
cp $new_icon $old_icon

# ------------------------------------------------------------------------------
# Dconf / Gsettings Default Value adjustments
# ------------------------------------------------------------------------------
echo
echo "*** Updating dconf / gsettings default values"
echo

# Updating dconf first to incorporate those direct entries first.
dconf update

# MAIN System schemas: we have placed our override file in this directory
# Sending any "error" to null (if key not found don't want to worry user)
glib-compile-schemas /usr/share/glib-2.0/schemas/ > /dev/null 2>&1 || true;

# ------------------------------------------------------------------------------
# Finished
# ------------------------------------------------------------------------------
echo
echo "*** Script Exit: wasta-gnome-postinst.sh"
echo

exit 0
