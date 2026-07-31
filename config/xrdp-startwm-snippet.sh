# Append to /etc/xrdp/startwm.sh, before the final "exec /etc/X11/Xsession"
# block. Sets a specific keyboard layout automatically for RDP sessions --
# swap "de" for your own layout code (e.g. "us", "gb", "fr").

( sleep 3; setxkbmap de )&
