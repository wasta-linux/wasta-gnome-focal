#!/bin/bash

# GDM3 requires that this script be named "Default" and placed in:
#   /etc/gdm3/PostLogin/ or /etc/gdm3/PreSession/

START_EPOCH=$(date +%s)

DM=''
LOG="/var/log/wasta-multidesktop/wasta-gnome-login.log"


# ------------------------------------------------------------------------------
# Functions
# ------------------------------------------------------------------------------

# function: urldecode used to decode gnome picture-uri
# https://stackoverflow.com/questions/6250698/how-to-decode-url-encoded-string-in-shell
urldecode(){ : "${*//+/ }"; echo -e "${_//%/\\x}"; }

log_msg(){
    title='WGL'
    type='info'
    if [[ $1 == 'debug' ]]; then
        type='debug'
        title='WGL-DEBUG'
        shift
    fi
    msg="${title}: $@"
    if [[ $type == 'debug' ]]; then
        echo "$msg"
    elif [[ $type == 'info' ]]; then
        echo "$msg" | tee -a "$LOG"
    fi
}

script_exit(){
    END_EPOCH=$(date +%s)
    elapsed=$(( $END_EPOCH - $START_EPOCH ))
    log_msg 'debug' "Login script duration: $elapsed s"
    log_msg 'debug' "End of $0"
    exit $1
}


# ------------------------------------------------------------------------------
# Main processing
# ------------------------------------------------------------------------------

log_msg 'debug' "Start of $0"
mkdir -p '/var/log/wasta-multidesktop'
touch "$LOG"

# Determine display manager.
dm_pre=$(systemctl status display-manager.service | grep 'Main PID:' | awk -F'(' '{print $2}')
# Get rid of 2nd parenthesis.
dm_pre="${dm_pre::-1}"
if [[ $dm_pre == 'lightdm' ]] || [[ $dm_pre == 'gdm3' ]]; then
    DM=$dm_pre
else
    # Unsupported display manager!
    log_msg "$(date)"
    log_msg "Error: Display manager \"$dm_pre\" not supported."
    script_exit 1
fi

# Get current user and session name (can't depend on env at lightdm login).
if [[ $DM == 'gdm3' ]]; then
    CURR_USER=$USERNAME
    # TODO: Need a different way to verify wayland session.
    log_msg 'debug' "$(printenv)"
    session_cmd=$(journalctl | grep '/usr/bin/gnome-session' | tail -n1)
    # X:
    # GdmSessionWorker: start program: /usr/lib/gdm3/gdm-x-session --run-script \
    #   "env GNOME_SHELL_SESSION_MODE=ubuntu /usr/bin/gnome-session --systemd --session=ubuntu"
    # Wayland:
    # /usr/lib/gdm-wayland-session[<pid>]: dbus-daemon[<pid>]: [session uid=<uid> pid=<pid>] ...
    pat='s/.*--session=(.*)"/\1/'
    CURR_SESSION=$(echo $session_cmd | sed -r "$pat")
elif [[ $DM == 'lightdm' ]]; then
    CURR_USER=$(grep -a "User .* authorized" /var/log/lightdm/lightdm.log | \
        tail -1 | sed 's@.*User \(.*\) authorized@\1@')
    CURR_SESSION=$(grep -a "Greeter requests session" /var/log/lightdm/lightdm.log | \
        tail -1 | sed 's@.*Greeter requests session \(.*\)@\1@')
fi

# Exit if not wasta-gnome or ubuntu session.
if [[ $CURR_SESSION != wasta-gnome ]] \
    && [[ $CURR_SESSION != ubuntu ]] \
    && [[ $CURR_SESSION != ubuntu-wayland ]]; then
    log_msg "$(date)"
    log_msg "Session not supported: $CURR_SESSION"
    script_exit 1
fi

# Exit if no CURR_USER (shouldn't happen).
if [[ ! $CURR_USER ]]; then
    log_msg "$(date)"
    log_msg "User not identified."
    script_exit 1
fi

# Write initial log entries.
log_msg "$(date)"
log_msg "Using $DM"
log_msg "Current session: $CURR_SESSION"
log_msg "Current user: $CURR_USER"

# Reset ...app-folders folder-children if it's currently set as ['Utilities', 'YaST']
key_path='org.gnome.desktop.app-folders'
key='folder-children'
curr_children=$(sudo --user=$CURR_USER gsettings get "$key_path" "$key")
if [[ $curr_children = "['Utilities', 'YaST']" ]] || \
    [[ $curr_children = "['Utilities', 'Sundry', 'YaST']" ]]; then
    sudo --user=$CURR_USER --set-home dbus-launch gsettings reset "$key_path" "$key" 2>&1 >/dev/null | tee -a "$LOG"
    log_msg "Reset gsettings $key_path $key"
fi

# Make adjustments if using lightdm and exit.
if [[ $DM == 'lightdm' ]]; then
    if [[ -e /usr/share/dbus-1/services/org.gnome.ScreenSaver.service.disabled ]]; then
        mv /usr/share/dbus-1/services/org.gnome.ScreenSaver.service{.disabled,}
        log_msg "Enabled gnome-screensaver."
    else
        # gnome-screensaver not previously disabled at login.
        log_msg "gnome-screensaver not disabled prior to lightdm login"
    fi
    script_exit 0
fi

# Incorporating additional items from wasta-login so as not to depend on wasta-multidesktop:
#   - ensure that background image is carried over from cinnamon (TODO: what about ubuntu?)
#   - set default preferences for Nautilus and Nemo (TODO: can't this be handled in a gschema overrides file?)
#   - hide cinnamon-specific apps
#   - disable cinnamon-specific services
#   - ensure gnome-specific apps are shown
#   - enable gnome-specific services
#   - store session name in PREV_SESSION_FILE
#   - ensure user owns their .cache, .config, and .dbus folders.
#   - kill off extraneous dbus-daemon processes launched by this script.

# From this point on the script makes the following assumptions:
#   - wasta-multidesktop is not installed
#   - display-manager is gdm3 rather than lightdm


# ------------------------------------------------------------------------------
# Initial Setup
# ------------------------------------------------------------------------------

log_msg 'debug' "Initial setup started..."
# Get user's previous session.
PREV_SESSION_FILE=/var/log/wasta-multidesktop/$CURR_USER-prev-session
touch "$PREV_SESSION_FILE"
PREV_SESSION=$(cat "$PREV_SESSION_FILE")
log_msg "User's previous session: $PREV_SESSION"

# Now send CURR_SESS to PREV_SESSION_FILE for next run.
echo "$CURR_SESSION" > "$PREV_SESSION_FILE"

# Get initial dconf and dbus pids.
PID_DCONF=$(pidof dconf-service)
PID_DBUS=$(pidof dbus-daemon)
log_msg 'debug' "Initial pids: dconf-service: $PID_DCONF; dbus-daemon: $PID_DBUS"

#DIR=/usr/share/wasta-multidesktop

# xfconfd: started but shouldn't be running (likely residual from previous
#   logged out xfce session)
#if [ "$(pidof xfconfd)" ]; then
#    killall xfconfd | tee -a $LOG
#fi

# ------------------------------------------------------------------------------
# Store current backgrounds
# ------------------------------------------------------------------------------
if [[ -x /usr/bin/cinnamon ]]; then
    #cinnamon: "file://" precedes filename
    #2018-12-18 rik: will do urldecode but not currently necessary for cinnamon
    key_path="org.cinnamon.desktop.background"
    key="picture-uri"
    CINNAMON_BG_URL=$(sudo --user=$CURR_USER --set-home dbus-launch gsettings get "$key_path" "$key" || true;)
    CINNAMON_BG=$(urldecode $CINNAMON_BG_URL)
    log_msg 'debug' "User's cinnamon background: $CINNAMON_BG"
    log_msg 'debug' "dbus-daemon pids: $(pidof dbus-daemon)"
fi

if [[ -x /usr/bin/gnome-shell ]]; then
    #gnome: "file://" precedes filename
    #2018-12-18 rik: urldecode necessary for gnome IF picture-uri set in gnome AND
    #   unicode characters present
    key_path="org.gnome.desktop.background"
    key="picture-uri"
    GNOME_BG_URL=$(sudo --user=$CURR_USER --set-home dbus-launch gsettings get "$key_path" "$key" || true;)
    GNOME_BG=$(urldecode $GNOME_BG_URL)
    log_msg 'debug' "User's gnome background: $GNOME_BG"
    log_msg 'debug' "dbus-daemon pids: $(pidof dbus-daemon)"
fi

AS_FILE="/var/lib/AccountsService/users/$CURR_USER"
if [[ -e "$AS_FILE" ]]; then
    # Lightdm 1.26 uses a more standardized syntax for storing user backgrounds.
    #   Since individual desktops would need to re-work how to set user backgrounds
    #   for use by lightdm we are doing it manually here to ensure compatiblity
    #   for all desktops
    if [[ ! $(grep "BackgroundFile=" $AS_FILE) ]]; then
        # Error, so BackgroundFile needs to be added to AS_FILE
        echo  >> $AS_FILE
        echo "[org.freedesktop.DisplayManager.AccountsService]" >> $AS_FILE
        echo "BackgroundFile=''" >> $AS_FILE
    fi
    # Retrieve current AccountsService user background
    AS_BG=$(sed -n "s@BackgroundFile=@@p" $AS_FILE)
    log_msg 'debug' "User background in $AS_FILE: $AS_BG"
fi

#if [[ -x /usr/bin/xfce4-session ]]; then
#    XFCE_DEFAULT_SETTINGS="/etc/xdg/xdg-xfce/xfce4/"
#    XFCE_SETTINGS="/home/$CURR_USER/.config/xfce4/"
#    #if ! [ -e $XFCE_SETTINGS ];
#    #then
#    #    if [ $DEBUG ];
#    #    then
#    #        echo "Creating xfce4 settings folder for user" | tee -a $LOGFILE
#    #    fi
#    #    mkdir -p $XFCE_SETTINGS
#    #    # cp -r $XFCE_DEFAULT_SETTINGS $XFCE_SETTINGS
#    #fi
#
#    XFCE_DEFAULT_DESKTOP="/etc/xdg/xdg-xfce/xfce4/xfconf/xfce-perchannel-xml/xfce4-desktop.xml"
#    XFCE_DESKTOP="/home/$CURR_USER/.config/xfce4/xfconf/xfce-perchannel-xml/xfce4-desktop.xml"
#    if ! [ -e $XFCE_DESKTOP ];
#    then
#        if [ $DEBUG ];
#        then
#            echo "Creating xfce4-desktop.xml for user" | tee -a $LOGFILE
#        fi
#        mkdir -p $XFCE_SETTINGS/xfconf/xfce-perchannel-xml/
#        cp $XFCE_DEFAULT_DESKTOP $XFCE_DESKTOP
#    fi
#
#    # since XFCE has different images per display and display names are
#    # different, and also since xfce properly sets AccountService background
#    # when setting a new background image, we will just use AS as xfce bg.
#    XFCE_BG=$AS_BG
#
#    #xfce: NO "file://" preceding filename
#    #XFCE_BG=$(xmlstarlet sel -T -t -m \
#    #    '//channel[@name="xfce4-desktop"]/property[@name="backdrop"]/property[@name="screen0"]/property[@name="monitorVirtual-1"]/property[@name="workspace0"]/property[@name="last-image"]/@value' \
#    #    -v . -n $XFCE_DESKTOP)
#    # not wanting to use xfconf-query because it starts xfconfd which then makes
#    # it difficult to change user settings.
#    #XFCE_BG=$(su "$CURR_USER" -c "dbus-launch xfconf-query -p /backdrop/screen0/monitor0/workspace0/last-image -c xfce4-desktop")
#fi

## Ensure all .config files owned by user
# NDM: This is also done at the end of the script, so ignoring here.
#chown -R $CURR_USER:$CURR_USER /home/$CURR_USER/.config/

#if [ $DEBUG ];
#then
#    if [ -x /usr/bin/cinnamon ];
#    then
#        echo "cinnamon bg url encoded: $CINNAMON_BG_URL" | tee -a $LOGFILE
#        echo "cinnamon bg url decoded: $CINNAMON_BG" | tee -a $LOGFILE
#    fi
#    if [ -x /usr/bin/xfce4-session ];
#    then
#        echo "xfce bg: $XFCE_BG" | tee -a $LOGFILE
#    fi
#    if [ -x /usr/bin/gnome-shell ];
#    then
#        echo "gnome bg url encoded: $GNOME_BG_URL" | tee -a $LOGFILE
#        echo "gnome bg url decoded: $GNOME_BG" | tee -a $LOGFILE
#    fi
#
#    echo "as bg: $AS_BG" | tee -a $LOGFILE
#fi


# ------------------------------------------------------------------------------
# ALL Session Adjustments
# ------------------------------------------------------------------------------
log_msg 'debug' "Adjustments for all sessions started..."
# SYSTEM level fixes:
# - we want app-adjustments to run every login to ensure that any updated
#   apps don't revert the customizations.
# - Triggering with 'at' so this login script is not delayed as
#   app-adjustments can run asynchronously.

# TODO: What to do about app-adjustments, which is installed by wasta-multidesktop?
#echo "$DIR/scripts/app-adjustments.sh $*" | at now || true;

# USER level fixes:
# Ensure Nautilus not showing hidden files (power users may be annoyed)
if [[ -x /usr/bin/nautilus ]]; then
    key_path="org.gnome.nautilus.preferences"
    key="show-hidden-files"
    value="false"
    sudo --user=$CURR_USER --set-home dbus-launch gsettings set "$key_path" "$key" "$value" || true;
fi

# Set Nemo preferences.
if [[ -x /usr/bin/nemo ]]; then
    # Ensure Nemo not showing hidden files (power users may be annoyed)
    key_path="org.nemo.preferences"
    key="show-hidden-files"
    value="false"
    sudo --user=$CURR_USER --set-home dbus-launch gsettings set "$key_path" "$key" "$value" || true;

    # Ensure Nemo not showing "location entry" (text entry), but rather "breadcrumbs"
    key_path="org.nemo.preferences"
    key="show-location-entry"
    value="false"
    sudo --user=$CURR_USER --set-home dbus-launch gsettings set "$key_path" "$key" "$value" || true;

    # Ensure Nemo sorting by name
    key_path="org.nemo.preferences"
    key="default-sort-order"
    value="'name'"
    sudo --user=$CURR_USER --set-home dbus-launch gsettings set "$key_path" "$key" "$value" || true;

    # Ensure Nemo sidebar showing
    key_path="org.nemo.window-state"
    key="start-with-sidebar"
    value="true"
    sudo --user=$CURR_USER --set-home dbus-launch gsettings set "$key_path" "$key" "$value" || true;

    # Ensure Nemo sidebar set to 'places'
    key_path="org.nemo.window-state"
    key="side-pane-view"
    value="'places'"
    sudo --user=$CURR_USER --set-home dbus-launch gsettings set "$key_path" "$key" "$value" || true;
fi

# copy in zim prefs if don't already exist (these make trayicon work OOTB)
# TODO: "DIR" doesn't exist when using gdm3 without wasta-multidesktop.
#if ! [[ -e /home/$CURR_USER/.config/zim/preferences.conf ]]; then
#    sudo --user=$CURR_USER cp -r $DIR/resources/skel/.config/zim /home/$CURR_USER/.config/zim
#fi

# 20.04 not needed?????
# skypeforlinux: if autostart exists patch it to launch as indicator
#   (this fixes icon size in xfce and fixes menu options for all desktops)
#   (needs to be run every time because skypeforlinux re-writes this launcher
#    every time it is started)
#   https://askubuntu.com/questions/1033599/how-to-remove-skypes-double-icon-in-ubuntu-18-04-mate-tray
#if [ -e /home/$CURR_USER/.config/autostart/skypeforlinux.desktop ];
#then
    # appindicator compatibility + manual minimize (xfce can't mimimize as
    # the "insides" of the window are minimized and don't exist but the
    # empty window frame remains behind: so close Skype window after 10 seconds)
#    desktop-file-edit --set-key=Exec --set-value='sh -c "env XDG_CURRENT_DESKTOP=Unity /usr/bin/skypeforlinux %U && sleep 10 && wmctrl -c Skype"' \
#        /home/$CURR_USER/.config/autostart/skypeforlinux.desktop
#fi

# --------------------------------------------------------------------------
# SYNC to PREV_SESSION (mainly for background picture)
# --------------------------------------------------------------------------
case "$PREV_SESSION" in

#cinnamon)
#    # apply Cinnamon settings to other DEs
#    if [ $DEBUG ];
#    then
#        echo "Previous Session Cinnamon: Sync to other DEs" | tee -a $LOGFILE
#    fi
#
#    if [ -x /usr/bin/gnome-shell ];
#    then
#        # sync Cinnamon background to GNOME background
#        su "$CURR_USER" -c "dbus-launch gsettings set org.gnome.desktop.background picture-uri $CINNAMON_BG" || true;
#    fi
#
#    if [ -x /usr/bin/xfce4-session ];
#    then
#        # first make sure xfconfd not running or else change won't load
#        #killall xfconfd
#
#        # sync Cinnamon background to XFCE background
#        NEW_XFCE_BG=$(echo "$CINNAMON_BG" | sed "s@'file://@@" | sed "s@'\$@@")
#        if [ $DEBUG ];
#        then
#            echo "Attempting to set NEW_XFCE_BG: $NEW_XFCE_BG" | tee -a $LOGFILE
#        fi
#        #su "$CURR_USER" -c "dbus-launch xfce4-set-wallpaper $NEW_XFCE_BG" || true;
#
#    # ?? why did I have this too? Doesn't sed below work?? maybe not....
#        #xmlstarlet ed --inplace -u \
#        #    '//channel[@name="xfce4-desktop"]/property[@name="backdrop"]/property[@name="screen0"]/property[@name="monitorVirtual-1"]/property[@name="workspace0"]/property[@name="last-image"]/@value' \
#        #    -v "$NEW_XFCE_BG" $XFCE_DESKTOP
#
#        #set ALL properties with name "last-image" to use value of new background
#        sed -i -e 's@\(name="last-image"\).*@\1 type="string" value="'"$NEW_XFCE_BG"'"/>@' \
#            $XFCE_DESKTOP
#
#    fi
#
#    # sync Cinnamon background to AccountsService background
#    NEW_AS_BG=$(echo "$CINNAMON_BG" | sed "s@file://@@")
#    if [ "$AS_BG" != "$NEW_AS_BG" ];
#    then
#        sed -i -e "s@\(BackgroundFile=\).*@\1$NEW_AS_BG@" $AS_FILE
#    fi
#;;

ubuntu|ubuntu-xorg|gnome|gnome-flashback-metacity|gnome-flashback-compiz|wasta-gnome)
    # apply GNOME settings to other DEs
    #if [ $DEBUG ];
    #then
    #    echo "Previous Session GNOME: Sync to other DEs" | tee -a $LOGFILE
    #fi

    if [[ -x /usr/bin/cinnamon ]]; then
        # sync GNOME background to Cinnamon background
        key_path="org.cinnamon.desktop.background"
        key="picture-uri"
        value="$GNOME_BG"
        sudo --user=$CURR_USER --set-home dbus-launch gsettings set "$key_path" "$key" "$value" || true;
    fi

    #if [ -x /usr/bin/xfce4-session ];
    #then
    #    # first make sure xfconfd not running or else change won't load
    #    #killall xfconfd
    #
    #    # sync GNOME background to XFCE background
    #    NEW_XFCE_BG=$(echo "$GNOME_BG" | sed "s@'file://@@" | sed "s@'\$@@")
    #    if [ $DEBUG ];
    #    then
    #        echo "Attempting to set NEW_XFCE_BG: $NEW_XFCE_BG" | tee -a $LOGFILE
    #    fi
    #    #su "$CURR_USER" -c "dbus-launch xfce4-set-wallpaper $NEW_XFCE_BG" || true;
    #
    # ?? why did I have this too? Doesn't sed below work?? maybe not....
    #        xmlstarlet ed --inplace -u \
    #        '//channel[@name="xfce4-desktop"]/property[@name="backdrop"]/property[@name="screen0"]/property[@name="monitorVirtual-1"]/property[@name="workspace0"]/property[@name="last-image"]/@value' \
    #        -v "$NEW_XFCE_BG" $XFCE_DESKTOP
    #
    #    #set ALL properties with name "last-image" to use value of new background
    #    sed -i -e 's@\(name="last-image"\).*@\1 type="string" value="'"$NEW_XFCE_BG"'"/>@' \
    #        $XFCE_DESKTOP
    #fi

    # sync GNOME background to AccountsService background
    NEW_AS_BG=$(echo "$GNOME_BG" | sed "s@file://@@")
    if [[ -e $AS_FILE ]] && [[ "$AS_BG" != "$NEW_AS_BG" ]]; then
        sed -i -e "s@\(BackgroundFile=\).*@\1$NEW_AS_BG@" $AS_FILE
        log_msg 'debug' "User background path saved to $AS_FILE"
    fi
;;

#xfce|xubuntu)
#    # apply XFCE settings to other DEs
#    #XFCE_BG_URL=$(urlencode $XFCE_BG)
#    XFCE_BG_NO_QUOTE=$(echo "$XFCE_BG" | sed "s@'@@g")
#
#    if [ $DEBUG ];
#    then
#        echo "Previous Session XFCE: Sync to other DEs" | tee -a $LOGFILE
#        #echo "xfce bg url: $XFCE_BG_URL" | tee -a $LOGFILE
#    fi
#
#    if [ -x /usr/bin/cinnamon ];
#    then
#        # sync XFCE background to Cinnamon background
#        su "$CURR_USER" -c "dbus-launch gsettings set org.cinnamon.desktop.background picture-uri 'file://$XFCE_BG_NO_QUOTE'" || true;
#    fi
#
#    if [ -x /usr/bin/gnome-shell ];
#    then
#        # sync XFCE background to GNOME background
#        su "$CURR_USER" -c "dbus-launch gsettings set org.gnome.desktop.background picture-uri 'file://$XFCE_BG_NO_QUOTE'" || true;
#    fi
#
# 20.04: I believe XFCE is properly setting AS so not repeating here
#    # sync XFCE background to AccountsService background
#    NEW_AS_BG="'$XFCE_BG'"
#    if [ "$AS_BG" != "$NEW_AS_BG" ];
#    then
#        sed -i -e "s@\(BackgroundFile=\).*@\1$NEW_AS_BG@" $AS_FILE
#    fi
#;;

*)
    # $PREV_SESSION unknown
    log_msg 'debug' "Unsupported previous session: $PREV_SESSION"
    log_msg 'debug' "Session NOT sync'd to other sessions."
;;

esac

# ------------------------------------------------------------------------------
# Processing based on current session
# ------------------------------------------------------------------------------
log_msg 'debug' "Adjustments for current session started..."
#case "$CURR_SESSION" in
#cinnamon)
#    # ==========================================================================
#    # ACTIVE SESSION: CINNAMON
#    # ==========================================================================
#    if [ $DEBUG ];
#    then
#        echo "processing based on CINNAMON session" | tee -a $LOGFILE
#    fi
#
#    # NDM: nautilus-desktop not used in focal.
#    # Nautilus may be active: kill (will not error if not found)
#    #if [ "$(pidof nautilus-desktop)" ];
#    #then
#    #    if [ $DEBUG ];
#    #    then
#    #        echo "nautilus running (TOP) and needs killed: $(pidof nautilus-desktop)" | tee -a $LOGFILE
#    #    fi
#    #    killall nautilus-desktop | tee -a $LOGFILE
#    #fi
#
#    # --------------------------------------------------------------------------
#    # CINNAMON Settings
#    # --------------------------------------------------------------------------
#    # SHOW CINNAMON items
#
#    if [ -e /usr/share/applications/cinnamon-online-accounts-panel.desktop ];
#    then
#        desktop-file-edit --remove-key=NoDisplay \
#            /usr/share/applications/cinnamon-online-accounts-panel.desktop || true;
#    fi
#
#    if [ -e /usr/share/applications/cinnamon-settings-startup.desktop ];
#    then
#        desktop-file-edit --remove-key=NoDisplay \
#            /usr/share/applications/cinnamon-settings-startup.desktop || true;
#    fi
#
#    if [ -x /usr/bin/nemo ];
#    then
#        desktop-file-edit --remove-key=NoDisplay \
#            /usr/share/applications/nemo.desktop || true;
#
#        # allow nemo to draw the desktop
#        su "$CURR_USER" -c "dbus-launch gsettings set org.nemo.desktop desktop-layout 'true::false'" || true;
#
#        # Ensure Nemo default folder handler
#        sed -i \
#            -e 's@\(inode/directory\)=.*@\1=nemo.desktop@' \
#            -e 's@\(application/x-gnome-saved-search\)=.*@\1=nemo.desktop@' \
#            /etc/gnome/defaults.list \
#            /usr/share/applications/defaults.list || true;
#    fi
#
#    if [ -e /usr/share/applications/nemo-compare-preferences.desktop ];
#    then
#        desktop-file-edit --remove-key=NoDisplay \
#            /usr/share/applications/nemo-compare-preferences.desktop || true;
#    fi
#
#    # ENABLE cinnamon-screensaver
#    if [ -e /usr/share/dbus-1/services/org.cinnamon.ScreenSaver.service.disabled ];
#    then
#        if [ $DEBUG ];
#        then
#            echo "enabling cinnamon-screensaver for cinnamon session" | tee -a $LOGFILE
#        fi
#        mv /usr/share/dbus-1/services/org.cinnamon.ScreenSaver.service{.disabled,}
#    fi
#
#    # --------------------------------------------------------------------------
#    # Ubuntu/GNOME Settings
#    # --------------------------------------------------------------------------
#    # HIDE Ubuntu/GNOME items
#    if [ -e /usr/share/applications/alacarte.desktop ];
#    then
#        desktop-file-edit --set-key=NoDisplay --set-value=true \
#            /usr/share/applications/alacarte.desktop || true;
#    fi
#
#    # Blueman-applet may be active: kill (will not error if not found)
#    if [ "$(pgrep blueman-applet)" ];
#    then
#        killall blueman-applet | tee -a $LOGFILE
#    fi
#
#    if [ -e /usr/share/applications/blueman-manager.desktop ];
#    then
#        desktop-file-edit --set-key=NoDisplay --set-value=true \
#            /usr/share/applications/blueman-manager.desktop || true;
#    fi
#
#    if [ -e /usr/share/applications/gnome-online-accounts-panel.desktop ];
#    then
#        desktop-file-edit --set-key=NoDisplay --set-value=true \
#            /usr/share/applications/gnome-online-accounts-panel.desktop || true;
#    fi
#
#    # Gnome Startup Applications
#    if [ -e /usr/share/applications/gnome-session-properties.desktop ];
#    then
#        desktop-file-edit --set-key=NoDisplay --set-value=true \
#            /usr/share/applications/gnome-session-properties.desktop || true;
#    fi
#
#    if [ -e /usr/share/applications/gnome-tweak-tool.desktop ];
#    then
#        desktop-file-edit --set-key=NoDisplay --set-value=true \
#            /usr/share/applications/gnome-tweak-tool.desktop || true;
#    fi
#
#    if [ -e /usr/share/applications/org.gnome.Nautilus.desktop ];
#    then
#        desktop-file-edit --set-key=NoDisplay --set-value=true \
#            /usr/share/applications/org.gnome.Nautilus.desktop || true;
#
#        # NDM: nautilus-desktop not used in focal.
#        # Nautilus may be active: kill (will not error if not found)
#        #if [ "$(pidof nautilus-desktop)" ];
#        #then
#        #    if [ $DEBUG ];
#        #    then
#        #        echo "nautilus running (MID) and needs killed: $(pidof nautilus-desktop)" | tee -a $LOGFILE
#        #    fi
#        #    killall nautilus-desktop | tee -a $LOGFILE
#        #fi
#    fi
#
#    if [ -e /usr/share/applications/org.gnome.Nautilus.desktop ];
#    then
#        desktop-file-edit --set-key=NoDisplay --set-value=true \
#            /usr/share/applications/org.gnome.Nautilus.desktop || true;
#    fi
#
#    # Prevent Gnome from drawing the desktop (for Xubuntu, Nautilus is not
#    #   installed but these settings were still true, thus not allowing nemo
#    #   to draw the desktop. So set to false all the time even if nautilus not
#    #   installed.
#    if [ -x /usr/bin/gnome-shell ];
#    then
#        su "$CURR_USER" -c 'dbus-launch gsettings set org.gnome.desktop.background show-desktop-icons false' || true;
#        su "$CURR_USER" -c 'dbus-launch gsettings set org.gnome.desktop.background draw-background false' || true;
#    fi
#
#    if [ -e /usr/share/applications/nautilus-compare-preferences.desktop ];
#    then
#        desktop-file-edit --set-key=NoDisplay --set-value=true \
#            /usr/share/applications/nautilus-compare-preferences.desktop || true;
#    fi
#
#    # ENABLE notify-osd
#    if [ -e /usr/share/dbus-1/services/org.freedesktop.Notifications.service.disabled ];
#    then
#        if [ $DEBUG ];
#        then
#            echo "enabling notify-osd for cinnamon session" | tee -a $LOGFILE
#        fi
#        mv /usr/share/dbus-1/services/org.freedesktop.Notifications.service{.disabled,}
#    fi
#
#    # --------------------------------------------------------------------------
#    # XFCE Settings
#    # --------------------------------------------------------------------------
#    # Thunar: hide (only installed for bulk-rename-tool)
#    if [ -e /usr/share/applications/thunar.desktop ];
#    then
#        desktop-file-edit --set-key=NoDisplay --set-value=true \
#            /usr/share/applications/thunar.desktop || true;
#    fi
#
#    if [ -e /usr/share/applications/thunar-settings.desktop ];
#    then
#        desktop-file-edit --set-key=NoDisplay --set-value=true \
#            /usr/share/applications/thunar-settings.desktop || true;
#    fi
#
#    if [ $DEBUG ];
#    then
#        if [ -x /usr/bin/nemo ];
#        then
#            echo "end cinnamon detected - NEMO show desktop icons: $(su $CURR_USER -c 'dbus-launch gsettings get org.nemo.desktop desktop-layout')" | tee -a $LOGFILE
#        fi
#
#        if [ -x /usr/bin/gnome-shell ];
#        then
#            echo "end cinnamon detected - NAUTILUS show desktop icons: $(su $CURR_USER -c 'dbus-launch gsettings get org.gnome.desktop.background show-desktop-icons')" | tee -a $LOGFILE
#            echo "end cinnamon detected - NAUTILUS draw background: $(su $CURR_USER -c 'dbus-launch gsettings get org.gnome.desktop.background draw-background')" | tee -a $LOGFILE
#        fi
#    fi
#
## ****BIONIC NOT SURE IF NEEDED
##    #again trying to set nemo to draw....
##    su "$CURR_USER" -c 'dbus-launch gsettings set org.nemo.desktop show-desktop-icons true'
##    su "$CURR_USER" -c 'dbus-launch gsettings set org.gnome.desktop.background show-desktop-icons false'
##    su "$CURR_USER" -c 'dbus-launch gsettings set org.gnome.desktop.background draw-background false'
##
##    ****BIONIC NOT SURE IF NEEDED
##    if [ $DEBUG ];
##    then
##        echo "after nemo draw desk again NEMO show desktop icons: $(su $CURR_USER -c 'dbus-launch gsettings get org.nemo.desktop show-desktop-icons')" | tee -a $LOGFILE
##        echo "after nemo draw desk again NAUTILUS show desktop icons: $(su $CURR_USER -c 'dbus-launch gsettings get org.gnome.desktop.background show-desktop-icons')" | tee -a $LOGFILE
##        echo "after nemo draw desk again NAUTILUS draw background: $(su $CURR_USER -c 'dbus-launch gsettings get org.gnome.desktop.background draw-background')" | tee -a $LOGFILE
##    fi
#;;

#ubuntu|ubuntu-xorg|gnome|gnome-flashback-metacity|gnome-flashback-compiz|wasta-gnome)
# ==========================================================================
# ACTIVE SESSION: WASTA-GNOME
# ==========================================================================
#if [ $DEBUG ];
#then
#    echo "processing based on UBUNTU / GNOME session" | tee -a $LOGFILE
#fi

non_gnome_apps=(
    nemo.desktop
    cinnamon-online-accounts-panel.desktop
    nemo-compare-preferences.desktop
    thunar.desktop
    thunar-settings.desktop
)
log_msg 'debug' "Hiding non-GNOME apps from the desktop user..."
for app in $non_gnome_apps; do
    if [[ -e /usr/share/applications/$app ]]; then
        desktop-file-edit --set-key=NoDisplay --set-value=true /usr/share/applications/$app || true;
    fi
done


# --------------------------------------------------------------------------
# CINNAMON Settings
# --------------------------------------------------------------------------
if [[ -x /usr/bin/nemo ]]; then
    #desktop-file-edit --set-key=NoDisplay --set-value=true \
    #    /usr/share/applications/nemo.desktop || true;

    # ****BIONIC: don't think necessary (nemo-desktop now handles desktop)
    # prevent nemo from drawing the desktop
    # su "$CURR_USER" -c "dbus-launch gsettings set org.nemo.desktop desktop-layout 'true::false'"

    # Nemo may be active: kill (will not error if not found)
    if [[ "$(pidof nemo-desktop)" ]]; then
        log_msg 'debug' "killing old nemo-desktop process: $(pidof nemo-desktop)"
        killall nemo-desktop
    fi
fi

#if [[ -e /usr/share/applications/cinnamon-online-accounts-panel.desktop ]]; then
#    desktop-file-edit --set-key=NoDisplay --set-value=true \
#        /usr/share/applications/cinnamon-online-accounts-panel.desktop || true;
#fi
#
#f [[ -e /usr/share/applications/nemo-compare-preferences.desktop ]]; then
#    desktop-file-edit --set-key=NoDisplay --set-value=true \
#        /usr/share/applications/nemo-compare-preferences.desktop || true;
#fi

# DISABLE cinnamon-screensaver
if [[ -e /usr/share/dbus-1/services/org.cinnamon.ScreenSaver.service ]]; then
    log_msg 'debug' "Disabling cinnamon-screensaver for gnome/ubuntu session."
    mv /usr/share/dbus-1/services/org.cinnamon.ScreenSaver.service{,.disabled}
fi

# --------------------------------------------------------------------------
# Ubuntu/GNOME Settings
# --------------------------------------------------------------------------
# SHOW GNOME Items
gnome_apps=(
    alacarte.desktop
    blueman-manager.desktop
    gnome-online-accounts-panel.desktop
    gnome-session-properties.desktop
    gnome-tweak-tool.desktop
    org.gnome.Nautilus.desktop
    nautilus-compare-preferences.desktop
    software-properties-gnome.desktop
)
log_msg 'debug' "Ensuring that GNOME apps are visible to the desktop user..."
for app in $gnome_apps; do
    if [[ -e /usr/share/applications/$app ]]; then
        desktop-file-edit --remove-key=NoDisplay /usr/share/applications/$app || true;
    fi
done

#if [[ -e /usr/share/applications/alacarte.desktop ]]; then
#    desktop-file-edit --remove-key=NoDisplay \
#        /usr/share/applications/alacarte.desktop || true;
#fi
#
#if [[ -e /usr/share/applications/blueman-manager.desktop ]]; then
#    desktop-file-edit -remove-key=NoDisplay \
#        /usr/share/applications/blueman-manager.desktop || true;
#fi
#
#if [[ -e /usr/share/applications/gnome-online-accounts-panel.desktop ]]; then
#    desktop-file-edit --remove-key=NoDisplay \
#        /usr/share/applications/gnome-online-accounts-panel.desktop || true;
#fi

# Gnome Startup Applications
#if [[ -e /usr/share/applications/gnome-session-properties.desktop ]]; then
#    desktop-file-edit --remove-key=NoDisplay \
#        /usr/share/applications/gnome-session-properties.desktop || true;
#fi
#
#if [[ -e /usr/share/applications/gnome-tweak-tool.desktop ]]; then
#    desktop-file-edit --remove-key=NoDisplay \
#        /usr/share/applications/gnome-tweak-tool.desktop || true;
#fi

if [[ -e /usr/share/applications/org.gnome.Nautilus.desktop ]]; then
    log_msg 'debug' "Making Nautilus adjustments..."
    #desktop-file-edit --remove-key=NoDisplay \
    #    /usr/share/applications/org.gnome.Nautilus.desktop || true;

    # Allow Nautilus to draw the desktop
    key_path="org.gnome.desktop.background"
    key="show-desktop-icons"
    value="true"
    sudo --user=$CURR_USER --set-home dbus-launch gsettings set "$key_path" "$key" "$value" || true;
    key_path="org.gnome.desktop.background"
    key="draw-background"
    value="true"
    sudo --user=$CURR_USER --set-home dbus-launch gsettings set "$key_path" "$key" "$value" || true;

    # Ensure Nautilus default folder handler
    sed -i \
        -e 's@\(inode/directory\)=.*@\1=org.gnome.Nautilus.desktop@' \
        -e 's@\(application/x-gnome-saved-search\)=.*@\1=org.gnome.Nautilus.desktop@' \
        /etc/gnome/defaults.list \
        /usr/share/applications/defaults.list || true;
fi

#if [[ -e /usr/share/applications/nautilus-compare-preferences.desktop ]]; then
#    desktop-file-edit --remove-key=NoDisplay \
#        /usr/share/applications/nautilus-compare-preferences.desktop || true;
#fi
#
#if [[ -e /usr/share/applications/software-properties-gnome.desktop ]]; then
#    desktop-file-edit --remove-key=NoDisplay \
#        /usr/share/applications/software-properties-gnome.desktop || true;
#fi

# ENABLE notify-osd
if [[ -e /usr/share/dbus-1/services/org.freedesktop.Notifications.service.disabled ]]; then
    #if [ $DEBUG ];
    #then
    #    echo "enabling notify-osd for gnome/ubuntu session" | tee -a $LOGFILE
    #fi
    log_msg 'debug' "Enabling notify-osd."
    mv /usr/share/dbus-1/services/org.freedesktop.Notifications.service{.disabled,}
fi

# --------------------------------------------------------------------------
# XFCE Settings
# --------------------------------------------------------------------------
# Thunar: hide (only installed for bulk-rename-tool)
#if [[ -e /usr/share/applications/thunar.desktop ]]; then
#    desktop-file-edit --set-key=NoDisplay --set-value=true \
#        /usr/share/applications/thunar.desktop || true;
#fi
#
#if [[ -e /usr/share/applications/thunar-settings.desktop ]]; then
#    desktop-file-edit --set-key=NoDisplay --set-value=true \
#        /usr/share/applications/thunar-settings.desktop || true;
#fi
#;;

#xfce|xubuntu)
#    # ==========================================================================
#    # ACTIVE SESSION: XFCE
#    # ==========================================================================
#    if [ $DEBUG ];
#    then
#        echo "processing based on XFCE session" | tee -a $LOGFILE
#    fi
#
#    # --------------------------------------------------------------------------
#    # CINNAMON Settings
#    # --------------------------------------------------------------------------
#    if [ -x /usr/bin/nemo ];
#    then
#        # nemo default file manager for wasta-xfce
#        desktop-file-edit --remove-key=NoDisplay \
#            /usr/share/applications/nemo.desktop || true;
#
#        # set nemo to draw the desktop
#        su "$CURR_USER" -c "dbus-launch gsettings set org.nemo.desktop desktop-layout 'true::false'" || true;
#
#        # ensure nemo can start if xfdesktop already running
#        su "$CURR_USER" -c "dbus-launch gsettings set org.nemo.desktop ignored-desktop-handlers \"['conky', 'xfdesktop']\"" || true;
#
#        # Ensure Nemo default folder handler
#        sed -i \
#            -e 's@\(inode/directory\)=.*@\1=nemo.desktop@' \
#            -e 's@\(application/x-gnome-saved-search\)=.*@\1=nemo.desktop@' \
#            /etc/gnome/defaults.list \
#            /usr/share/applications/defaults.list || true;
#
#        # nemo-desktop ends up running, but not showing desktop icons. It is
#        # something to do with how it is started, possible conflict with
#        # xfdesktop, or other. At user level need to killall nemo-desktop and
#        # restart, but many contorted ways of doing it directly here haven't
#        # been successful, so making it a user level autostart.
#
#        NEMO_RESTART="/home/$CURR_USER/.config/autostart/nemo-desktop-restart.desktop"
#        if ! [ -e "$NEMO_RESTART" ];
#        then
#            # create autostart
#            if [ $DEBUG ];
#            then
#                echo "linking nemo-desktop-restart for xfce compatibility" | tee -a $LOGFILE
#            fi
#            su $CURR_USER -c "mkdir -p /home/$CURR_USER/.config/autostart"
#            su $CURR_USER -c "ln -s $DIR/resources/nemo-desktop-restart.desktop $NEMO_RESTART"
#        fi
#    fi
#
#    if [ -e /usr/share/applications/nemo-compare-preferences.desktop ];
#    then
#        desktop-file-edit --remove-key=NoDisplay \
#            /usr/share/applications/nemo-compare-preferences.desktop || true;
#    fi
#
#    # DISABLE cinnamon-screensaver
#    if [ -e /usr/share/dbus-1/services/org.cinnamon.ScreenSaver.service ];
#    then
#        if [ $DEBUG ];
#        then
#            echo "disabling cinnamon-screensaver for xfce session" | tee -a $LOGFILE
#        fi
#        mv /usr/share/dbus-1/services/org.cinnamon.ScreenSaver.service{,.disabled}
#    fi
#
#    # --------------------------------------------------------------------------
#    # Ubuntu/GNOME Settings
#    # --------------------------------------------------------------------------
#
#    # HIDE Ubuntu/GNOME items
#    if [ -e /usr/share/applications/alacarte.desktop ];
#    then
#        desktop-file-edit --set-key=NoDisplay --set-value=true \
#            /usr/share/applications/alacarte.desktop || true;
#    fi
#
#    # Blueman-applet may be active: kill (will not error if not found)
#    if [ "$(pgrep blueman-applet)" ];
#    then
#        killall blueman-applet | tee -a $LOGFILE
#    fi
#
#    if [ -e /usr/share/applications/blueman-manager.desktop ];
#    then
#        desktop-file-edit --set-key=NoDisplay --set-value=true \
#            /usr/share/applications/blueman-manager.desktop || true;
#    fi
#
#    if [ -e /usr/share/applications/gnome-online-accounts-panel.desktop ];
#    then
#        desktop-file-edit --set-key=NoDisplay --set-value=true \
#            /usr/share/applications/gnome-online-accounts-panel.desktop || true;
#    fi
#
#    # Gnome Startup Applications
#    if [ -e /usr/share/applications/gnome-session-properties.desktop ];
#    then
#        desktop-file-edit --set-key=NoDisplay --set-value=true \
#            /usr/share/applications/gnome-session-properties.desktop || true;
#    fi
#
#    if [ -e /usr/share/applications/gnome-tweak-tool.desktop ];
#    then
#        desktop-file-edit --set-key=NoDisplay --set-value=true \
#            /usr/share/applications/gnome-tweak-tool.desktop || true;
#    fi
#
#    if [ -e /usr/share/applications/org.gnome.Nautilus.desktop ];
#    then
#        desktop-file-edit --set-key=NoDisplay --set-value=true \
#            /usr/share/applications/org.gnome.Nautilus.desktop || true;
#
#        # NDM: nautilus-desktop not used in focal.
#        # Nautilus may be active: kill (will not error if not found)
#        #if [ "$(pidof nautilus-desktop)" ];
#        #then
#        #    if [ $DEBUG ];
#        #    then
#        #        echo "nautilus running (MID) and needs killed: $(pidof nautilus-desktop)" | tee -a $LOGFILE
#        #    fi
#        #    killall nautilus-desktop | tee -a $LOGFILE
#        #fi
#    fi
#
#    if [ -e /usr/share/applications/org.gnome.Nautilus.desktop ];
#    then
#        desktop-file-edit --set-key=NoDisplay --set-value=true \
#            /usr/share/applications/org.gnome.Nautilus.desktop || true;
#    fi
#
#    if [ -e /usr/share/applications/nautilus-compare-preferences.desktop ];
#    then
#        desktop-file-edit --set-key=NoDisplay --set-value=true \
#            /usr/share/applications/nautilus-compare-preferences.desktop || true;
#    fi
#
#    # Prevent Gnome from drawing the desktop (for Xubuntu, Nautilus is not
#    #   installed but these settings were still true, thus not allowing nemo
#    #   to draw the desktop. So set to false all the time even if nautilus not
#    #   installed.
#    if [ -x /usr/bin/gnome-shell ];
#    then
#        su "$CURR_USER" -c 'dbus-launch gsettings set org.gnome.desktop.background show-desktop-icons false' || true;
#        su "$CURR_USER" -c 'dbus-launch gsettings set org.gnome.desktop.background draw-background false' || true;
#    fi
#
#    # DISABLE notify-osd (xfce uses xfce4-notifyd)
#    if [ -e /usr/share/dbus-1/services/org.freedesktop.Notifications.service ];
#    then
#        if [ $DEBUG ];
#        then
#            echo "disabling notify-osd for xfce session" | tee -a $LOGFILE
#        fi
#        mv /usr/share/dbus-1/services/org.freedesktop.Notifications.service{,.disabled}
#    fi
#
#    # --------------------------------------------------------------------------
#    # XFCE Settings
#    # --------------------------------------------------------------------------
#
#    # Thunar: hide (only installed for bulk-rename-tool)
#    if [ -e /usr/share/applications/thunar.desktop ];
#    then
#        desktop-file-edit --set-key=NoDisplay --set-value=true \
#            /usr/share/applications/thunar.desktop || true;
#    fi
#
#    if [ -e /usr/share/applications/thunar-settings.desktop ];
#    then
#        desktop-file-edit --set-key=NoDisplay --set-value=true \
#            /usr/share/applications/thunar-settings.desktop || true;
#    fi
#
#    # xfdesktop used for background but does NOT draw desktop icons
#    # (app-adjustments adds XFCE to OnlyShowIn to trigger nemo-desktop)
#    # NOTE: XFCE_DESKTOP file created above in background sync
#
#    # first: determine if element exists
#    # style: 0 - None
#    #        2 - File/launcher icons
#    DESKTOP_STYLE=""
#    DESKTOP_STYLE=$(xmlstarlet sel -T -t -m \
#        '//channel[@name="xfce4-desktop"]/property[@name="desktop-icons"]/property[@name="style"]/@value' \
#        -v . -n $XFCE_DESKTOP)
#
#    # second: create element else update element
#    if [ "$DESKTOP_STYLE" == "" ];
#    then
#        # create key
#        if [ $DEBUG ];
#        then
#            echo "creating xfce4-desktop/desktop-icons/style element" | tee -a $LOGFILE
#        fi
#        xmlstarlet ed --inplace \
#            -s '//channel[@name="xfce4-desktop"]/property[@name="desktop-icons"]' \
#                -t elem -n "property" -v "" \
#            -i '//channel[@name="xfce4-desktop"]/property[@name="desktop-icons"]/property[last()]' \
#                -t attr -n "name" -v "style" \
#            -i '//channel[@name="xfce4-desktop"]/property[@name="desktop-icons"]/property[@name="style"]' \
#                -t attr -n "type" -v "int" \
#            -i '//channel[@name="xfce4-desktop"]/property[@name="desktop-icons"]/property[@name="style"]' \
#                -t attr -n "value" -v "0" \
#            $XFCE_DESKTOP
#    else
#        # update key
#        xmlstarlet ed --inplace \
#            -u '//channel[@name="xfce4-desktop"]/property[@name="desktop-icons"]/property[@name="style"]/@value' \
#            -v "0" $XFCE_DESKTOP
#    fi
#
#    # skypeforlinux: can't start minimized in xfce or will end up with an
#    # empty window frame that can't be closed (without re-activating the
#    # empty frame by clicking on the panel icon).  Note above skypeforlinux
#    # autolaunch will always start it minimized (after 10 second delay)
##    if [ -e /home/$CURR_USER/.config/skypeforlinux/settings.json ];
##    then
##        # set launchMinimized = false
##        sed -i -e 's@"app.launchMinimized":true@"app.launchMinimized":false@' \
##            /home/$CURR_USER/.config/skypeforlinux/settings.json
##    fi
#
#    # xfce clock applet loses it's config if opened and closed without first
#    #    stopping the xfce4-panel.  So reset to defaults
#    # https://askubuntu.com/questions/959339/xfce-panel-clock-disappears
##    XFCE_DEFAULT_PANEL="/etc/xdg/xdg-xfce/xfce4/panel/default.xml"
##    XFCE_PANEL="/home/$CURR_USER/.config/xfce4/xfconf/xfce-perchannel-xml/xfce4-panel.xml"
##    if [ -e "$XFCE_PANEL" ];
##    then
#        # using xmlstarlet since can't be sure of clock plugin #
##        DEFAULT_DIGITAL_FORMAT=$(xmlstarlet sel -T -t -m \
##            '//channel[@name="xfce4-panel"]/property[@name="plugins"]/property[@value="clock"]/property[@name="digital-format"]/@value' \
##           -v . -n $XFCE_DEFAULT_PANEL)
#        #    DIGITAL_FORMAT=$(xmlstarlet sel -T -t -m \
#        #        '//channel[@name="xfce4-panel"]/property[@name="plugins"]/property[@value="clock"]/property[@name="digital-format"]/@value' \
#        #        -v . -n $XFCE_PANEL)
##        BLANK_DIGITAL_FORMAT=$(grep '"digital-format" type="string" value=""' $XFCE_PANEL)
#
# #       if [ "$BLANK_DIGITAL_FORMAT" ];
#  #      then
##            if [ $DEBUG ];
##            then
##                echo "xfce4-panel clock digital-format removed: resetting" | tee -a $LOGFILE
##            fi
#            # rik: below doesn't work since when $XFCE_PANEL put in ~/.config the NAMEs
#            # are removed from the plugin properties: don't want to rely on plugin number so
#            # instead will have to hack it with sed
#            #        xmlstarlet ed --inplace -u \
#            #            '//channel[@name="xfce4-panel"]/property[@name="plugins"]/property[@value="clock"]/property[@name="digital-format"]/@value' \
#            #            -v "$DEFAULT_DIGITAL_FORMAT" $XFCE_PANEL
##            sed -i -e 's@\("digital-format" type="string" value=\)""@\1"'"$DEFAULT_DIGITAL_FORMAT"'"@' \
##                $XFCE_PANEL
##        fi
#
# #       DEFAULT_TOOLTIP_FORMAT=$(xmlstarlet sel -T -t -m \
#  #          '//channel[@name="xfce4-panel"]/property[@name="plugins"]/property[@value="clock"]/property[@name="tooltip-format"]/@value' \
#   #         -v . -n $XFCE_DEFAULT_PANEL)
#    #    BLANK_TOOLTIP_FORMAT=$(grep '"tooltip-format" type="string" value=""' $XFCE_PANEL)
#
#     #   if [ "$BLANK_TOOLTIP_FORMAT" ];
#      #  then
#       #     if [ $DEBUG ];
#        #    then
#         #       echo "xfce4-panel clock tooltip-format removed: resetting" | tee -a $LOGFILE
#          #  fi
#           # sed -i -e 's@\("tooltip-format" type="string" value=\)""@\1"'"$DEFAULT_TOOLTIP_FORMAT"'"@' $XFCE_PANEL
#  #      fi
# #   fi
#;;
#
#*)
#    # ==========================================================================
#    # ACTIVE SESSION: not supported yet
#    # ==========================================================================
#    #if [ $DEBUG ];
#    #then
#    #    echo "desktop session not supported" | tee -a $LOGFILE
#    #fi
#
#    # Thunar: show (even though only installed for bulk-rename-tool)
#    if [[ -e /usr/share/applications/thunar.desktop ]]; then
#        desktop-file-edit --set-key=NoDisplay --set-value=false \
#            /usr/share/applications/thunar.desktop || true;
#    fi
#
#    if [[ -e /usr/share/applications/thunar-settings.desktop ]]; then
#        desktop-file-edit --set-key=NoDisplay --set-value=false \
#            /usr/share/applications/thunar-settings.desktop || true;
#    fi
#;;
#
#esac

# ------------------------------------------------------------------------------
# FINISHED
# ------------------------------------------------------------------------------
log_msg 'debug' "Cleaning up..."

#if [ $DEBUG ];
#then
#    echo "final settings:" | tee -a $LOGFILE
#
#    if [ -x /usr/bin/cinnamon ];
#    then
#        CINNAMON_BG_NEW=$(su "$CURR_USER" -c 'dbus-launch gsettings get org.cinnamon.desktop.background picture-uri')
#        echo "cinnamon bg NEW: $CINNAMON_BG_NEW" | tee -a $LOGFILE
#    fi
#
#    if [ -x /usr/bin/xfce4-session ];
#    then
#        #XFCE_BG_NEW=$(su "$CURR_USER" -c "dbus-launch xfconf-query -p /backdrop/screen0/monitor0/workspace0/last-image -c xfce4-desktop" || true;)
#        XFCE_BG_NEW=$(xmlstarlet sel -T -t -m \
#            '//channel[@name="xfce4-desktop"]/property[@name="backdrop"]/property[@name="screen0"]/property[@name="monitorVirtual-1"]/property[@name="workspace0"]/property[@name="last-image"]/@value' \
#            -v . -n $XFCE_DESKTOP)
#        echo "xfce bg NEW: $XFCE_BG_NEW" | tee -a $LOGFILE
#    fi
#
#    if [ -x /usr/bin/gnome-shell ];
#    then
#        GNOME_BG_NEW=$(su "$CURR_USER" -c 'dbus-launch gsettings get org.gnome.desktop.background picture-uri')
#        echo "gnome bg NEW: $GNOME_BG_NEW" | tee -a $LOGFILE
#    fi
#
#    AS_BG_NEW=$(sed -n "s@BackgroundFile=@@p" "$AS_FILE")
#    echo "as bg NEW: $AS_BG_NEW" | tee -a $LOGFILE
#
#    if [ -x /usr/bin/nemo ];
#    then
#        echo "NEMO show desktop icons: $(su $CURR_USER -c 'dbus-launch gsettings get org.nemo.desktop desktop-layout')" | tee -a $LOGFILE
#    fi
#
#    if [ -x /usr/bin/nautilus ];
#    then
#        echo "NAUTILUS show desktop icons: $(su $CURR_USER -c 'dbus-launch gsettings get org.gnome.desktop.background show-desktop-icons')" | tee -a $LOGFILE
#        echo "NAUTILUS draw background: $(su $CURR_USER -c 'dbus-launch gsettings get org.gnome.desktop.background draw-background')" | tee -a $LOGFILE
#    fi
#fi

# Kill dconf processes that were potentially triggered by this script that need
#   to be restarted in order for changes to take effect: the selected desktop
#   will restart what is needed.
#killall dconf-service
END_PID_DCONF=$(pidof dconf-service)
if [[ ! "$PID_DCONF" ]]; then
    # no previous DCONF pid so remove all current
    REMOVE_PID_DCONF=$END_PID_DCONF
else
    REMOVE_PID_DCONF=$(echo $END_PID_DCONF | sed -e "s@$PID_DCONF@@")
fi

END_PID_DBUS=$(pidof dbus-daemon)
if ! [[ "$PID_DBUS" ]]; then
    # no previous DBUS pid so remove all current
    REMOVE_PID_DBUS=$END_PID_DBUS
else
    REMOVE_PID_DBUS=$(echo $END_PID_DBUS | sed -e "s@$PID_DBUS@@")
fi

# Debug messages about extraneous pids.
log_msg 'debug' "dconf: initial pids: $PID_DCONF"
log_msg 'debug' "dconf: current pids: $END_PID_DCONF"
log_msg 'debug' "dconf: pids to kill: $REMOVE_PID_DCONF"
log_msg 'debug' "dbus: initial pids: $PID_DBUS"
log_msg 'debug' "dbus: current pids: $END_PID_DBUS"
log_msg 'debug' "dbus: pids to kill: $REMOVE_PID_DBUS"

# Kill extraneous pids.
log_msg 'debug' "Killing additional dconf processes..."
kill -9 $REMOVE_PID_DCONF
log_msg 'debug' "Killing additional dbus-daemon processes..."
kill -9 $REMOVE_PID_DBUS

# Ensure files correctly owned by user
log_msg 'debug' "Ensuring user owns \$HOME/.cache, \$HOME/.config, \$HOME/.dbus..."
chown -R $CURR_USER:$CURR_USER /home/$CURR_USER/.cache/
chown -R $CURR_USER:$CURR_USER /home/$CURR_USER/.config/
chown -R $CURR_USER:$CURR_USER /home/$CURR_USER/.dbus/

script_exit 0
