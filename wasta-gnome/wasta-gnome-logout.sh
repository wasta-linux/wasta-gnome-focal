#!/bin/bash

# Get current session name (can't depend on env at login).
CURR_SESSION=$(grep -a "Greeter requests session" /var/log/lightdm/lightdm.log | \
    tail -1 | sed 's@.*Greeter requests session \(.*\)@\1@')

# Exit if not wasta-gnome session.
if [[ $CURR_SESSION != wasta-gnome ]]; then
    exit 0
fi

# Disable gnome-screensaver.
if [[ -e /usr/share/dbus-1/services/org.gnome.ScreenSaver.service ]]; then
    mv /usr/share/dbus-1/services/org.gnome.ScreenSaver.service{,.disabled}
else
    # gnome-screensaver not properly installed for some reason.
    continue
fi
