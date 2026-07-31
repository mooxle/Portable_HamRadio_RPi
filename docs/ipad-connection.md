# Connecting from an iPad (or Mac/Windows) over USB-C

Once the [USB-C Ethernet gadget](usb-gadget-ethernet.md) is set up, the Pi
is reachable at `192.168.7.2` over the cable — no Wi-Fi needed. (At home
over Wi-Fi instead of the USB-C cable, use `<hostname>.local` or your
router's DHCP list — see
["Finding the Pi's IP address"](../README.md#finding-the-pis-ip-address)
in the main README; the steps below are otherwise identical, just swap the
address.) Two tools cover everything you need:

- **SSH** (Termius) — for scripting: switching Wi-Fi networks, running the
  GPS time-sync script, checking logs, rebooting.
- **RDP** (Microsoft Remote Desktop) — for the actual desktop session:
  running WSJT-X and GridTracker2 as you would on any PC.

## SSH via Termius

[Termius](https://termius.com/) is a widely-used cross-platform SSH client
with a solid iOS app.

1. Install Termius from the App Store.
2. Add a new host:
   - **Address:** `192.168.7.2`
   - **Username:** your Pi user
   - **Port:** `22` (or whatever your SSH server listens on)
3. Add your SSH key (Termius supports importing a private key, or
   generating one on-device and adding the public key to the Pi's
   `~/.ssh/authorized_keys`) — avoid password auth if you can.
4. Connect — you now have a full terminal on the Pi from the iPad. Handy
   for `./gpssync.sh`, `wifi-home`/`wifi-hotspot`, or just checking
   `systemctl status`.

## RDP via Microsoft Remote Desktop

The **Microsoft Remote Desktop** app (free, App Store) is noticeably more
stable for this over a USB/Wi-Fi link than VNC-based alternatives in
practice.

1. Install "Microsoft Remote Desktop" from the App Store.
2. Add a PC:
   - **PC name:** `192.168.7.2`
   - **User account:** your Pi user's credentials
3. Connect — you get the full LXDE desktop session, exactly like sitting
   in front of the Pi with a monitor attached. This is where you actually
   run WSJT-X/GridTracker2, watch waterfalls, work split-screen, etc.
4. Touch tips: pinch-to-zoom works for reading small WSJT-X text: the
   Pi's `xrdp` session resolution follows whatever the client negotiates,
   so on an iPad you'll generally get a sharper, better-fitted display
   than trying to mirror a fixed desktop resolution.

## Why both, not just one

RDP alone doesn't give you a shell for quick scripting or Wi-Fi switching
without opening a terminal emulator inside the desktop session — SSH is
faster for that. RDP alone can't run WSJT-X's GUI for you — you need the
desktop for that. Together, they cover the whole workflow from a single
cable and a tablet.
