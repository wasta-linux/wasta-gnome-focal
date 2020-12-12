#!/bin/bash

LOG="/var/log/wasta-multidesktop/wasta-gnome-login-errors"
date | tee -a "${LOG}"

# Get current user and session name (can't depend on env at login).
CURR_USER=$(grep -a "User .* authorized" /var/log/lightdm/lightdm.log | \
    tail -1 | sed 's@.*User \(.*\) authorized@\1@')
CURR_SESSION=$(grep -a "Greeter requests session" /var/log/lightdm/lightdm.log | \
    tail -1 | sed 's@.*Greeter requests session \(.*\)@\1@')

# Exit if not wasta-gnome session.
if [[ $CURR_SESSION != wasta-gnome ]]; then
    exit 0
fi

# Enable gnome-screensaver.
if [[ -e /usr/share/dbus-1/services/org.gnome.ScreenSaver.service.disabled ]]; then
    mv /usr/share/dbus-1/services/org.gnome.ScreenSaver.service{.disabled,}
else
    # gnome-screensaver not previously disabled at login.
    echo "gnome-screensaver not disabled prior to login" | tee -a "${LOG}"
fi

# Reset ...app-folders folder-children if it's currently set as ['Utilities', 'YaST']
key_path='org.gnome.desktop.app-folders'
key='folder-children'
curr_children=$(sudo --user=$CURR_USER gsettings get "$key_path" "$key")
if [[ $curr_children = "['Utilities', 'YaST']" ]] || \
    [[ $curr_children = "['Utilities', 'Sundry', 'YaST']" ]]; then
    sudo --user=$CURR_USER --set-home dbus-launch gsettings reset "$key_path" "$key" 2>&1 >/dev/null | tee -a "${LOG}"
fi
echo | tee -a "${LOG}"
