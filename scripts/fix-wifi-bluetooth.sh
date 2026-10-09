#!/usr/bin/env bash
# deja bien el wifi y bluetooth de la RTL8821CE
# - iwd y wpa_supplicant peleaban por wlan0 y se caia el wifi
# - ips/fwlps no existen en rtw88, se cambian por las opciones reales
set -e

# NetworkManager usa wpa_supplicant, iwd sobra
sudo systemctl disable --now iwd 2>/dev/null || true
sudo systemctl mask iwd
printf '[device]\nwifi.backend=wpa_supplicant\n' | sudo tee /etc/NetworkManager/conf.d/wifi-backend.conf >/dev/null

sudo rm -f /etc/modprobe.d/rtl8821ce.conf
printf 'options rtw88_pci disable_aspm=y\noptions rtw88_core disable_lps_deep=y\n' | sudo tee /etc/modprobe.d/rtw88.conf >/dev/null
echo "options btusb enable_autosuspend=n" | sudo tee /etc/modprobe.d/btusb.conf >/dev/null

sudo rfkill unblock bluetooth || true
sudo systemctl restart bluetooth

sudo systemctl restart NetworkManager

echo "listo, reinicia para que carguen las opciones del driver"
