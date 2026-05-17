#!/bin/bash

INTERFACE="enp3s0"
IPADDR="192.168.77.1/24"
TFTP_DIR="/srv/tftp"

echo "====================================="
echo "   DOOM Raspberry Pi TFTP Startup"
echo "====================================="

echo
echo "[1/4] Configurando interface Ethernet..."

sudo ip addr flush dev $INTERFACE
sudo ip addr add $IPADDR dev $INTERFACE
sudo ip link set $INTERFACE up

echo
echo "[2/4] Reiniciando servidor TFTP..."

sudo systemctl restart tftpd-hpa

echo
echo "[3/4] Status da interface:"
ip addr show $INTERFACE

echo
echo "[4/4] Arquivos disponíveis no TFTP:"
ls -lh $TFTP_DIR

echo
echo "====================================="
echo "TFTP pronto para boot do Raspberry Pi"
echo "====================================="

