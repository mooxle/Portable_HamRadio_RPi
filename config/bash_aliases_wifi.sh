# Add to ~/.bashrc (or ~/.bash_aliases if you keep one).
# Indices (0/1) must match the order of "network={}" blocks in your own
# wpa_supplicant.conf -- adjust if you have more/different networks.

alias wifi-home="sudo ip addr flush dev wlan0 && sudo wpa_cli -i wlan0 select_network 0 && echo 'Waiting for home Wi-Fi...' && sleep 5 && sudo dhclient -v wlan0 && sudo systemctl restart avahi-daemon"
alias wifi-hotspot="sudo ip addr flush dev wlan0 && sudo wpa_cli -i wlan0 select_network 1 && echo 'Waiting for hotspot...' && sleep 8 && sudo dhclient -v wlan0 && sudo systemctl restart avahi-daemon"
alias wifi-status="sudo wpa_cli -i wlan0 status | grep -E 'ssid|ip_address|wpa_state'"
