````markdown
# DOOM on Raspberry Pi B+ with Buildroot

Embedded DOOM appliance running on Raspberry Pi B+ using:

- Buildroot
- U-Boot
- TFTP boot
- NFS rootfs
- vc4 DRM framebuffer
- SDL fbcon
- HDMI ALSA audio
- PRBoom
- MIDI via Timidity

---

# Features

- Fullscreen DOOM
- HDMI audio
- MIDI music
- USB keyboard input
- 320x200 optimized rendering
- Network boot via TFTP/NFS

---

# Tested Hardware

- Raspberry Pi Model B+
- HDMI monitor
- USB keyboard
- Ethernet connection

---

````



---

# Network Configuration

Host IP:

```text
192.168.77.1
```

Target IP:

```text
192.168.77.2
```

Assign host IP:

```bash
sudo ip addr add 192.168.77.1/24 dev <interface>
sudo ip link set <interface> up
```

---

# TFTP Setup

Install:

```bash
sudo apt install tftpd-hpa
```

TFTP directory:

```text
/srv/tftp
```

Copy kernel and DTB:

```bash
cp output/images/zImage /srv/tftp/
cp output/images/*.dtb /srv/tftp/
```

---

# NFS Root Filesystem

Install:

```bash
sudo apt install nfs-kernel-server
```

Rootfs directory:

```text
/srv/nfs/rpi-rootfs
```

Update rootfs:

```bash
sudo rsync -av --delete output/target/ /srv/nfs/rpi-rootfs/
```

Edit:

```text
/etc/exports
```

Add:

```text
/srv/nfs/rpi-rootfs *(rw,sync,no_subtree_check,no_root_squash)
```

Apply:

```bash
sudo exportfs -ra
```

---

# Raspberry Pi config.txt

```text
kernel=u-boot.bin

hdmi_group=1
hdmi_mode=4

dtoverlay=vc4-kms-v3d
```

---

# U-Boot Configuration

Interrupt autoboot and run:

```bash
setenv bootargs 'console=ttyAMA0,115200 root=/dev/nfs rw nfsroot=192.168.77.1:/srv/nfs/rpi-rootfs,tcp,v3 ip=192.168.77.2::192.168.77.1:255.255.255.0:rpi:eth0:off rootwait'

setenv bootcmd 'tftp ${kernel_addr_r} zImage; tftp ${fdt_addr_r} bcm2835-rpi-b-plus.dtb; bootz ${kernel_addr_r} - ${fdt_addr_r}'

setenv preboot 'usb start'

setenv stdin serial

saveenv
```

---

# MIDI Setup

Install Freepats on host:

```bash
sudo apt install freepats
```

Copy patches:

```bash
sudo mkdir -p /srv/nfs/rpi-rootfs/usr/share/timidity

sudo cp -r /usr/share/midi/freepats \
    /srv/nfs/rpi-rootfs/usr/share/timidity/
```

Copy configuration:

```bash
sudo cp /etc/timidity/freepats.cfg \
    /srv/nfs/rpi-rootfs/etc/timidity.cfg
```

Edit:

```text
/srv/nfs/rpi-rootfs/etc/timidity.cfg
```

Replace:

```text
dir /usr/share/midi/freepats
```

With:

```text
dir /usr/share/timidity/freepats
```

---

# Run DOOM

```bash
export SDL_VIDEODRIVER=fbcon
export SDL_FBDEV=/dev/fb0

/usr/games/prboom \
    -width 320 \
    -height 200
```

---

# Notes

320x200 is recommended for Raspberry Pi B+ performance.

---

# License

DOOM WAD files are not included.

Users must provide their own IWAD files:

* DOOM
* DOOM II
* Freedoom

```
```
