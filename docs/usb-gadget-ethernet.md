# USB-C as an Ethernet gadget

This is what lets you plug the Pi directly into an iPad/MacBook/Windows
laptop over USB-C and control it as if it were a wired network device —
no Wi-Fi involved at all. Works on Pi models with a USB-C/OTG-capable
port (Pi 4, Pi Zero 2 W, CM4 carrier boards with OTG wired up, etc.).

**`/boot/firmware/config.txt`** (append):
```
dtoverlay=dwc2,dr_mode=peripheral
```

**`/boot/firmware/cmdline.txt`** (add `modules-load=dwc2,g_ether` — must
come *before* `rootwait`):
```
modules-load=dwc2,g_ether
```

**`/etc/network/interfaces.d/usb0`** (new file):
```
allow-hotplug usb0
iface usb0 inet static
  address 192.168.7.2
  netmask 255.255.255.0
```

After a reboot, the Pi enumerates as a USB Ethernet device on the host
computer, reachable at `192.168.7.2`. No DHCP needed — macOS/iPadOS/Windows
will automatically negotiate an address in the same `192.168.7.x` range once
the gadget is detected (some setups may need the host side confirmed/checked
manually the first time, depending on OS).

This coexists fine with Wi-Fi — the Pi can have Wi-Fi *and* the USB-C
gadget link active at the same time, useful if you want internet via
Wi-Fi while controlling the Pi over the direct USB cable.
