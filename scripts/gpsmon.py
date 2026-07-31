#!/usr/bin/env python3
"""
GPS Live Monitor — u-blox 7
Benötigt: gpsd, gpsd-clients
Aufruf:   python3 gpsmon.py
Beenden:  Strg+C
"""

import subprocess
import json
import os
import signal
import socket
import sys
from datetime import datetime

# ── ANSI Farben ───────────────────────────────────────────────────
RST = "\033[0m"
BLD = "\033[1m"
DIM = "\033[2m"
CYN = "\033[96m"
GRN = "\033[92m"
YLW = "\033[93m"
RED = "\033[91m"
WHT = "\033[97m"

W      = 44           # visuelle Innenbreite der Box
DEVICE = "/dev/ttyACM0"

proc         = None
started_gpsd = False

# ── Cleanup bei Strg+C ────────────────────────────────────────────
def cleanup(sig=None, frame=None):
    if proc:
        proc.terminate()
    if started_gpsd:
        subprocess.run(["sudo", "pkill", "gpsd"], capture_output=True)
    print("\033[?25h\033[0m\n")   # Cursor wieder einblenden
    sys.exit(0)

signal.signal(signal.SIGINT,  cleanup)
signal.signal(signal.SIGTERM, cleanup)

# ── Hilfsfunktionen ───────────────────────────────────────────────
def compass(deg):
    if deg is None:
        return "---"
    dirs = ["N","NNO","NO","ONO","O","OSO","SO","SSO",
            "S","SSW","SW","WSW","W","WNW","NW","NNW"]
    return dirs[round(deg / 22.5) % 16]

def fmt_lat(v):
    if v is None:
        return "---"
    return f"{abs(v):.6f}°  {'N' if v >= 0 else 'S'}"

def fmt_lon(v):
    if v is None:
        return "---"
    return f"{abs(v):.6f}°  {'E' if v >= 0 else 'W'}"

def plain_row(text):
    """Zeile mit einfachem Text — normales Padding"""
    return f"{CYN}│{RST}  {text:<{W}}  {CYN}│{RST}"

def color_row(plain, colored):
    """Zeile mit ANSI-Farbe — plain für Padding, colored für Ausgabe"""
    pad = " " * (W - len(plain))
    return f"{CYN}│{RST}  {colored}{pad}  {CYN}│{RST}"

def sep():
    return f"{CYN}├{'─' * (W + 4)}┤{RST}"

# ── Display ───────────────────────────────────────────────────────
def render(tpv, sky):
    mode = tpv.get("mode", 0)

    if   mode == 3: fix_p = "3D FIX";      fix_c = f"{GRN}{BLD}3D FIX{RST}"
    elif mode == 2: fix_p = "2D FIX";      fix_c = f"{YLW}{BLD}2D FIX{RST}"
    elif mode == 1: fix_p = "KEIN FIX";    fix_c = f"{RED}KEIN FIX{RST}"
    else:           fix_p = "Verbinde..."; fix_c = f"{DIM}Verbinde...{RST}"

    gps_time = gps_date = "---"
    if "time" in tpv:
        try:
            dt = datetime.fromisoformat(tpv["time"].replace("Z", "+00:00"))
            gps_time = dt.strftime("%H:%M:%S UTC")
            gps_date = dt.strftime("%d.%m.%Y")
        except Exception:
            pass

    lat   = tpv.get("lat")
    lon   = tpv.get("lon")
    alt   = tpv.get("alt")
    speed = tpv.get("speed")
    track = tpv.get("track")

    alt_s   = f"{alt:.1f} m"               if alt   is not None else "---"
    speed_s = f"{speed * 3.6:.1f} km/h"    if speed is not None else "---"
    track_s = f"{track:.0f}° ({compass(track)})" if track is not None else "---"

    sats = sky.get("satellites", [])
    used = sky.get("uSat", sum(1 for s in sats if s.get("used", False)))
    seen = sky.get("nSat", len(sats))
    bw   = 16
    fill = round(used / max(seen, 1) * bw)

    bar_plain = f"Satelliten:  {'X' * fill}{'.' * (bw - fill)}  {used:2d} / {seen}"
    bar_color = f"Satelliten:  {YLW}{'█' * fill}{'░' * (bw - fill)}{RST}  {used:2d} / {seen}"

    hint_p = "Aktualisiert ~1s   [Strg+C] Beenden"
    hint_c = f"{DIM}{hint_p}{RST}"

    host  = socket.gethostname()
    title = f" GPS MONITOR  |  {host} "

    return "\n".join([
        f"{CYN}┌{'─' * (W + 4)}┐{RST}",
        f"{CYN}│{BLD}{WHT}{title:^{W+4}}{RST}{CYN}│{RST}",
        sep(),
        color_row(f"Status:      {fix_p}",  f"Status:      {fix_c}"),
        plain_row(f"GPS-Zeit:    {gps_time}"),
        plain_row(f"GPS-Datum:   {gps_date}"),
        plain_row(f"Systemzeit:  {datetime.now().strftime('%H:%M:%S')} lokal"),
        sep(),
        plain_row(f"Latitude:    {fmt_lat(lat)}"),
        plain_row(f"Longitude:   {fmt_lon(lon)}"),
        plain_row(f"Hoehe:       {alt_s}"),
        sep(),
        color_row(bar_plain, bar_color),
        plain_row(f"Geschw.:     {speed_s}"),
        plain_row(f"Richtung:    {track_s}"),
        sep(),
        color_row(hint_p, hint_c),
        f"{CYN}└{'─' * (W + 4)}┘{RST}",
    ])

# ── Hauptprogramm ─────────────────────────────────────────────────
def main():
    global proc, started_gpsd

    if not os.path.exists(DEVICE):
        print(f"FEHLER: GPS-Stick nicht gefunden ({DEVICE})")
        sys.exit(1)

    # gpsd starten falls nicht aktiv
    if subprocess.run(["pgrep", "gpsd"], capture_output=True).returncode != 0:
        print("Starte GPS-Daemon...")
        subprocess.run(["sudo", "gpsd", DEVICE, "-n"], check=True)
        started_gpsd = True
        import time
        time.sleep(1)

    proc = subprocess.Popen(
        ["gpspipe", "-w"],
        stdout=subprocess.PIPE,
        text=True,
        bufsize=1
    )

    print("\033[?25l")  # Cursor ausblenden

    tpv, sky = {}, {}

    for line in proc.stdout:
        try:
            msg = json.loads(line.strip())
        except json.JSONDecodeError:
            continue

        cls = msg.get("class", "")
        if cls == "TPV":
            tpv = msg
        elif cls == "SKY":
            if "nSat" in msg or "satellites" in msg:
                sky = msg   # nur volle SKY-Pakete mit Satellitendaten
            else:
                continue    # abgespeckte DOP-only SKY ignorieren
        else:
            continue

        print("\033[H\033[J", end="")   # Bildschirm leeren
        print(render(tpv, sky))

if __name__ == "__main__":
    main()
