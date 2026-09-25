#!/usr/bin/env bash
set -e

BOLD='\033[1m'
GREEN='\033[0;32m'
BLUE='\033[0;34m'
NC='\033[0m'

echo -e "${BLUE}${BOLD}=== Reparando y optimizando Bluetooth ===${NC}"

# 1. Optimizar /etc/bluetooth/main.conf
if [ -f /etc/bluetooth/main.conf ]; then
    sudo sed -i -E 's/^[#[:space:]]*ControllerMode[[:space:]]*=.*/ControllerMode = dual/' /etc/bluetooth/main.conf
    sudo sed -i -E 's/^[#[:space:]]*FastConnectable[[:space:]]*=.*/FastConnectable = false/' /etc/bluetooth/main.conf
    sudo sed -i -E 's/^[#[:space:]]*AutoEnable[[:space:]]*=.*/AutoEnable = true/' /etc/bluetooth/main.conf
    sudo sed -i -E 's/^[#[:space:]]*FilterDiscoverable[[:space:]]*=.*/FilterDiscoverable = true/' /etc/bluetooth/main.conf
    sudo sed -i -E 's/^[#[:space:]]*TemporaryTimeout[[:space:]]*=.*/TemporaryTimeout = 10/' /etc/bluetooth/main.conf
    if ! grep -q "JustWorksRepairing" /etc/bluetooth/main.conf; then
        sudo sed -i '/\[General\]/a JustWorksRepairing = always' /etc/bluetooth/main.conf
    fi
    echo -e " ${GREEN}✔ /etc/bluetooth/main.conf optimizado (ControllerMode=dual, FilterDiscoverable=true, FastConnectable=false).${NC}"
fi

# 2. Desactivar autosuspend para chip Realtek
echo "options btusb enable_autosuspend=n" | sudo tee /etc/modprobe.d/btusb.conf >/dev/null
echo -e " ${GREEN}✔ Suspensión automática desactivada en btusb.${NC}"

# 3. Reiniciar servicio
sudo systemctl restart bluetooth
echo -e " ${GREEN}✔ Servicio bluetoothd reiniciado con éxito.${NC}"

echo ""
echo -e "${GREEN}${BOLD}¡Bluetooth reparado! Ahora puedes emparejar y conectar tus audífonos.${NC}"
