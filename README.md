# Pi FT8/USB-C Station

A pocket-sized, fully portable FT8/digital-modes station built on a
Raspberry Pi — controlled over a **USB-C Ethernet cable** from an iPad,
MacBook, or Windows laptop, with **no Wi-Fi required** to operate it.

## Why this setup

- **WSJT-X on a real desktop beats the mobile FT8 apps.** Native
  iOS/Android FT8 apps are convenient, but WSJT-X gives you full decode
  power, proper CAT rig control, adjustable audio/decode settings, and
  clean ADIF logging — things the phone apps generally can't match.
- **USB-C Ethernet gadget mode** turns the Pi into a wired "network
  appliance" you plug into your tablet/laptop — no Wi-Fi hotspot needed in
  the field, no fighting with flaky Wi-Fi at a POTA/SOTA site, just a
  cable and a fixed IP.
- **Runs headless**, controlled entirely via SSH (scripting, Wi-Fi
  switching, GPS time sync) and RDP (the actual WSJT-X/GridTracker2
  desktop), from whatever device you have on you — see
  [`docs/ipad-connection.md`](docs/ipad-connection.md).
- **GPS time sync fallback** for accurate FT8 timing when there's no
  internet/NTP in the field.

## Hardware

- Raspberry Pi 4 Model B (2GB+ RAM) or newer — this was built and tested
  on a Pi 4.
- microSD card (16GB+)
- USB-C cable (data-capable, not charge-only) to the controlling device
- Optional: USB GPS receiver (u-blox-based dongles work well with `gpsd`)
  for field time-sync without internet
- Your radio's CAT/audio interface (varies by rig)

## Base OS

[DietPi](https://dietpi.com/) on Debian (Raspberry Pi build) — lightweight,
headless-friendly, has a built-in first-boot automation file
(`dietpi.txt`) that covers most of the base setup below in one pass.

## Setup overview

1. **Flash DietPi**, pre-configure via `dietpi.txt`: locale, keyboard
   layout, timezone, hostname, Wi-Fi.
2. **Desktop + remote access:**
   ```
   sudo apt install git openssh-client xrdp xorgxrdp lxde lxde-core lightdm lightdm-gtk-greeter gpsd gpsd-clients gpsd-tools
   ```
   - `xrdp`/`xorgxrdp` — RDP server, so you can pull up the actual desktop
     session remotely. In practice, **use a proper RDP client app rather
     than VNC** — noticeably more stable over a USB-Ethernet or Wi-Fi link.
   - Keyboard layout for RDP sessions: append to `/etc/xrdp/startwm.sh`
     (see [`config/xrdp-startwm-snippet.sh`](config/xrdp-startwm-snippet.sh)
     — swap `de` for your own layout).
3. **USB-C Ethernet gadget mode** — the core trick that makes this
   "wireless-free" control possible. Full config in
   [`docs/usb-gadget-ethernet.md`](docs/usb-gadget-ethernet.md).
4. **Wi-Fi (optional, for internet/NTP/updates in the field):** two
   networks + swap aliases, see [`config/`](config/) below.
5. **WSJT-X + GridTracker2** — see Software section below.
6. **GPS time sync** — see Scripts section below.
7. **Connect from your tablet/phone/laptop** —
   [`docs/ipad-connection.md`](docs/ipad-connection.md).

## Finding the Pi's IP address

- **Over USB-C (in the field):** always fixed — **`192.168.7.2`** (see
  [`docs/usb-gadget-ethernet.md`](docs/usb-gadget-ethernet.md)). No lookup
  needed, ever — that's the whole point of the static gadget IP.
- **Over home Wi-Fi:** DHCP-assigned, so it can change. Two ways to find it:
  1. **mDNS/Bonjour hostname (easiest):** `avahi-daemon` is already part of
     this setup — it gets restarted on every Wi-Fi switch (see
     [`config/bash_aliases_wifi.sh`](config/bash_aliases_wifi.sh)) — so
     `ping <hostname>.local` or `ssh <user>@<hostname>.local` should just
     work from a Mac, iPhone/iPad, Linux box, or Windows with
     Bonjour/iTunes installed. `<hostname>` is whatever you set in
     `dietpi.txt` (e.g. if the hostname is `hampi`, use `hampi.local`).
  2. **Router's DHCP client list** — log into your router's admin page and
     look for the Pi's hostname among connected devices/DHCP leases, if
     mDNS isn't available on your particular network or client device.

## Software

- **WSJT-X** — official releases (Windows/macOS/Linux, including
  Linux ARM64 for Raspberry Pi) at
  <https://wsjtx.github.io/wsjtx/downloads.html> or directly via
  [GitHub releases](https://github.com/WSJTX/wsjtx/releases/latest)
  (look for the `linux-aarch64.deb` build). Configure `MyCall`/`MyGrid`,
  your CAT serial port, and enable UDP broadcast (default `127.0.0.1:2237`)
  so GridTracker2 can pick up decodes.
  > If you have a specific community-modified WSJT-X build you prefer
  > (e.g. tweaked UI layouts for small touchscreens), that obviously works
  > too — just track its source yourself, since `update_radio_apps.sh`
  > (see Scripts below) is written against the official releases and would
  > overwrite a modified build with the official one.
- **GridTracker2** — official downloads (including Linux ARM64/Raspberry
  Pi `.deb`) at
  <https://gridtracker.org/index.php/downloads/gridtracker-downloads>.
  Has a **built-in update checker**, so it's mostly self-maintaining once
  installed with internet access — just launch it occasionally online and
  watch for an update prompt. Connect it to WSJT-X's UDP port on first run.

Neither app comes from an apt repository, so regular `sudo apt upgrade`
won't ever touch them — that's expected, not a bug.
[`scripts/update_radio_apps.sh`](scripts/update_radio_apps.sh) checks both
against their official sources and installs newer versions when found (run
it by hand whenever you want to check — no cron, package installs deserve
a look at the output).

## Scripts (`scripts/`)

- **`update_radio_apps.sh`** — checks the official WSJT-X (GitHub releases
  API) and GridTracker2 (downloads page, best-effort) sources against what's
  installed, downloads and installs newer `.deb`s when found. Adjust the
  `WSJTX_ARCH_SUFFIX`/`GT_ARCH` variables at the top for non-ARM64 systems.
  Run: `./update_radio_apps.sh`.
### GPS hardware and how it's wired up

Tested with a cheap **u-blox 7-chipset USB GPS dongle** (widely sold under
many different brand names, usually a few euros/dollars) — any GPS receiver
that speaks standard NMEA 0183 over USB should work the same way, since
`gpsd` (not this project) is what actually understands the protocol.

- The dongle enumerates as a **USB CDC-ACM serial device** — no special
  driver needed. On the Pi it shows up as `/dev/ttyACM0` (as long as
  nothing else claims that device node first).
- **Find yours:** plug it in, then run `lsusb` (genuine u-blox USB
  receivers commonly register under u-blox AG's own vendor ID `1546`,
  though cheap dongles vary) and `dmesg | tail` right after plugging in —
  the kernel log line will tell you the exact `/dev/ttyACM*` (or
  `/dev/ttyUSB*` for dongles using a separate FTDI/CP210x USB-serial
  bridge chip instead of a native USB GPS chipset) it landed on.
- **If you also have another USB-serial device** (e.g. a rig's CAT
  interface), the device path can shift depending on what's plugged in and
  in which order — don't assume `/dev/ttyACM0` blindly, check `dmesg`
  after plugging the GPS in specifically. Both scripts below hardcode
  `/dev/ttyACM0` — edit the `DEVICE = "/dev/ttyACM0"` (`gpsmon.py`) /
  `DEVICE="/dev/ttyACM0"` (`gpssync.sh`) line at the top of each if yours
  differs.
- **Sanity-check the GPS independently of these scripts** with `cgps -s`
  (comes with `gpsd-clients`) — it talks straight to `gpsd` and shows raw
  fix/satellite data, useful for confirming the dongle itself is working
  before troubleshooting the custom scripts.
- Both scripts start `gpsd` themselves (`sudo gpsd $DEVICE -n`) if it isn't
  already running, and stop it again on exit/Ctrl-C — you don't need to
  manage the `gpsd` service separately.

### Scripts

- **`gpsmon.py`** — live terminal GPS monitor (fix status, position,
  altitude, speed, satellite count). Run: `python3 gpsmon.py`.
- **`gpssync.sh`** — sets the system clock precisely from a GPS fix, shows
  the correction delta in ms. Useful when there's no internet in the
  field. Run: `./gpssync.sh`.
- **Time-sync strategy:** run NTP continuously in the background (auto-syncs
  whenever internet is reachable) and use `gpssync.sh` only as the manual
  fallback when there's no internet at all — the two don't conflict. On
  DietPi specifically, the default NTP mode is "Boot + Daily" (syncs once,
  then stops), **not continuous** — switch to full daemon mode with:
  ```
  sudo /boot/dietpi/func/dietpi-set_software ntpd-mode 4
  ```
  On other distros, just make sure `systemd-timesyncd` (or `chrony`/`ntpd`)
  is enabled as a normal running service, not a one-shot.

## Wi-Fi switching (`config/`)

Two networks in `wpa_supplicant.conf` — your home Wi-Fi (for updates/NTP
at home) and a phone hotspot (for internet in the field) — switched via
shell aliases. See
[`config/wpa_supplicant.conf.example`](config/wpa_supplicant.conf.example)
and [`config/bash_aliases_wifi.sh`](config/bash_aliases_wifi.sh).

> **iPhone Personal Hotspot users:** enable **"Maximize Compatibility"**
> in Settings → Personal Hotspot. Without it, older/simpler Wi-Fi chips
> (like many Pi models) may fail to connect reliably — that setting forces
> 2.4GHz/WPA2, which is far more broadly compatible.

The `wifi-home`/`wifi-hotspot` aliases select networks by index
(`select_network 0`/`1`) — the index depends on the order networks are
listed in your own `wpa_supplicant.conf`, adjust if you add more networks.

## Optional: logbook sync example

[`scripts/sync_logbook.sh.example`](scripts/sync_logbook.sh.example) shows
a pattern for pulling your QSO log from a self-hosted logging platform
(the original was written for [Wavelog](https://www.wavelog.org/)) into
`~/.local/share/WSJT-X/wsjtx_log.adi`, so GridTracker2 picks it up. Adapt
the API calls to whatever logging platform you actually use — this is one
possible integration, not a requirement.

## Rebuild checklist

1. Flash DietPi, set locale/keyboard/timezone/hostname via `dietpi.txt`.
2. `dietpi-config` → Desktop: LXDE; SSH server: your choice (Dropbear is
   lighter-weight; OpenSSH is more standard/familiar).
3. Install packages (see Setup overview above), including `git` +
   `openssh-client` if you plan to keep this repo on the Pi itself.
4. Add the `setxkbmap` line to `/etc/xrdp/startwm.sh`.
5. Set up USB-C gadget Ethernet (`docs/usb-gadget-ethernet.md`).
6. Configure Wi-Fi networks + aliases, remember the iPhone hotspot
   compatibility setting if relevant.
7. Install WSJT-X + GridTracker2 from their official ARM64 packages,
   configure callsign/grid/CAT port/UDP.
8. Copy `scripts/` back to your home directory, adapt the logbook sync
   script if you use one.
9. Switch NTP to continuous mode (see Scripts section above).
10. Set up SSH/RDP access from your tablet/laptop —
    [`docs/ipad-connection.md`](docs/ipad-connection.md).

## License

MIT — see [`LICENSE`](LICENSE). This is a community recipe, not a
supported product — issues/PRs welcome, no guarantees.
