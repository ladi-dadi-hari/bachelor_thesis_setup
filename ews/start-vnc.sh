#!/bin/sh

rm -r /tmp/.X11-unix/
vncserver -kill :0
vncserver :0 -rfbport 5900 -geometry "1920x1000" -depth 24
x11vnc -display :0 -autoport -localhost -nopw -bg -xkb -ncache -ncache_cr -quiet -forever
/usr/share/novnc/utils/novnc_proxy --listen 5911 --vnc localhost:5900
kali-undercover

tail -f /dev/null
