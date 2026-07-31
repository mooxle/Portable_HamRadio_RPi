#!/bin/bash
# GPS Zeit-Synchronisation — Raspberry Pi / Linux
# Benötigt: gpsd, gpsd-clients
# Aufruf:   ./gpssync.sh

DEVICE="/dev/ttyACM0"

RST="\033[0m"
GRN="\033[92m"
YLW="\033[93m"
RED="\033[91m"
CYN="\033[96m"

echo -e "\n${YLW}>>> GPS Zeit-Sync — Raspberry Pi${RST}\n"

# ── GPS-Stick prüfen ─────────────────────────────────────
if [ ! -e "$DEVICE" ]; then
    echo -e "${RED}FEHLER: GPS-Stick nicht gefunden ($DEVICE)${RST}"
    exit 1
fi

# ── gpsd starten ─────────────────────────────────────────
echo ">>> Starte GPS-Daemon..."
sudo gpsd $DEVICE -n

# ── Auf Fix warten, GPS-Zeit UND Systemzeit gleichzeitig lesen ───
echo ">>> Warte auf GPS-Fix (max. 2 Minuten)..."

# Python liest GPS-Zeit und erfasst time.time() im selben Moment —
# so gibt es keine Verzögerung durch bash-Aufrufe dazwischen.
GPS_DATA=$(timeout 120 gpspipe -w | python3 -c "
import sys, json, time
for line in sys.stdin:
    try:
        msg = json.loads(line)
        if msg.get('class') == 'TPV' and msg.get('mode', 0) >= 2 and 'time' in msg:
            sys_now = time.time()          # Systemzeit ms-genau im selben Moment
            print(f\"{msg['time']}|{sys_now:.3f}\")
            break
    except:
        pass
")

if [ -z "$GPS_DATA" ]; then
    echo -e "${RED}>>> Kein Fix bekommen – Abbruch${RST}\n"
    sudo pkill gpsd 2>/dev/null
    exit 1
fi

GPS_TIME=$(echo "$GPS_DATA" | cut -d'|' -f1)
SYS_TIME=$(echo "$GPS_DATA" | cut -d'|' -f2)

echo ">>> Fix erhalten!  GPS-Zeit: $GPS_TIME"

# ── Zeit setzen ──────────────────────────────────────────
sudo date -s "$GPS_TIME" > /dev/null

echo -e "${GRN}>>> Systemzeit gesetzt: $(date)${RST}"

# ── Abweichung in ms berechnen und ausgeben ──────────────
python3 - "$GPS_TIME" "$SYS_TIME" << 'PYEOF'
import sys
from datetime import datetime, timezone

gps_str  = sys.argv[1]
sys_ts   = float(sys.argv[2])

try:
    gps_dt   = datetime.fromisoformat(gps_str.replace("Z", "+00:00"))
    delta_s  = sys_ts - gps_dt.timestamp()

    sign = "+" if delta_s >= 0 else "-"
    s    = abs(delta_s)

    if s < 1:
        fmt = f"{sign}{s * 1000:.0f} ms"
    elif s < 60:
        ms = round((s % 1) * 1000)
        fmt = f"{sign}{int(s)} s  {ms} ms"
    elif s < 3600:
        m, sec = divmod(int(s), 60)
        fmt = f"{sign}{m} Min {sec} s"
    else:
        h, rem = divmod(int(s), 3600)
        fmt = f"{sign}{h} h {rem // 60} Min"

    if s < 0.5:
        quality = "\033[92msehr gut\033[0m"
    elif s < 2:
        quality = "\033[92mgut\033[0m"
    elif s < 10:
        quality = "\033[93mleicht abgewichen\033[0m"
    elif s < 60:
        quality = "\033[93mmerklich abgewichen\033[0m"
    else:
        quality = "\033[91mstark abgewichen\033[0m"

    print(f"\n\033[96m>>> Uhrzeit-Korrektur: {fmt}  ({quality}\033[96m)\033[0m\n")

except Exception as e:
    print(f"Delta-Berechnung fehlgeschlagen: {e}")
PYEOF

# ── gpsd stoppen ─────────────────────────────────────────
echo ">>> Stoppe GPS..."
sudo pkill gpsd 2>/dev/null
