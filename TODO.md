- [x] Add extension to mute "____ is ready" notifications.
- [x] Fix "Esc" not working to close Overview.
- [x] Ensure that wasta-login.sh script gets properly run.
- [x] Test using "runuser -u $USER -- command..." instead of "sudo --user=$USER -H command..."
  - It works, but is it worth pushing another update just for that?
- [x] Reset app-folders folder-children:
    - need to check for "Utilities", "Sundry", and "YaST"
- [x] Add gnome-screensaver
- [x] Add Wasta's context menu options to Nautilus
- [x] Make notifications show up in bottom right corner.
- [x] Make app indicator icons appear in dash-to-panel.
- [x] Implement per-desktop gschema overrides.

### Tests
1. Verify that gnome screensaver is enabled on login and disabled on logout
```bash
# After login:
$ ls /usr/share/dbus-1/services/org.gnome.ScreenSaver.service*
ls /usr/share/dbus-1/services/org.gnome.ScreenSaver.service
# After logout:
$ ls /usr/share/dbus-1/services/org.gnome.ScreenSaver.service*
/usr/share/dbus-1/services/org.gnome.ScreenSaver.service.disabled
```
1. Verify that app-folders get reset if arbitrarily set to "['Utilities', 'YaST']".
```bash
# After login:
$ gsettings set org.gnome.desktop.app-folders folder-children "['Utilities', 'YaST']"
$ gnome-session-quit --logout
# After re-login:
$ gesttings get org.gnome.desktop.app-folders folder-children
['Graphics', 'AudioVideo', 'Network', 'Office', 'Development', 'System', 'Settings', 'Utility', 'Game', 'Education', 'Wasta']
```
1. Verify that gsettings changes get propagated.
