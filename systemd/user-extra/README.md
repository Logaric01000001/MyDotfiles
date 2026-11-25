Servicios de usuario específicos de proyectos (omniroute, vpsoracle, cloudflared, security-lab…).
Solo respaldo: `install.sh` NO los instala porque dependen de rutas de proyectos.
Restaurar a mano: `cp systemd/user-extra/* ~/.config/systemd/user/ && systemctl --user daemon-reload`.
