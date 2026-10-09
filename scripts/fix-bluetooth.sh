#!/usr/bin/env bash
set -e

conf=/etc/bluetooth/main.conf

if [ -f "$conf" ]; then
    sudo sed -i -E 's/^[#[:space:]]*ControllerMode[[:space:]]*=.*/ControllerMode = bredr/' "$conf"
    sudo sed -i -E 's/^[#[:space:]]*FastConnectable[[:space:]]*=.*/FastConnectable = false/' "$conf"
    sudo sed -i -E 's/^[#[:space:]]*AutoEnable[[:space:]]*=.*/AutoEnable = false/' "$conf"
    sudo sed -i -E 's/^[#[:space:]]*NameResolving[[:space:]]*=.*/NameResolving = true/' "$conf"
    sudo sed -i -E 's/^[#[:space:]]*RemoteNameRequestRetryDelay[[:space:]]*=.*/RemoteNameRequestRetryDelay = 5/' "$conf"
    sudo sed -i -E 's/^[#[:space:]]*FilterDiscoverable[[:space:]]*=.*/FilterDiscoverable = true/' "$conf"
    sudo sed -i -E 's/^[#[:space:]]*TemporaryTimeout[[:space:]]*=.*/TemporaryTimeout = 10/' "$conf"
    grep -q "JustWorksRepairing" "$conf" || sudo sed -i '/\[General\]/a JustWorksRepairing = always' "$conf"
fi

# el chip realtek se duerme y no vuelve
echo "options btusb enable_autosuspend=n" | sudo tee /etc/modprobe.d/btusb.conf >/dev/null

sudo systemctl restart bluetooth
echo "bluetooth listo"
