#!/usr/bin/env python3
import os
import shutil
import subprocess
import sys


class Colors:
    GREEN = "\033[32m"
    BLUE = "\033[34m"
    YELLOW = "\033[33m"
    RED = "\033[31m"
    RESET = "\033[0m"


def log(msg: str):
    print(f"\n{Colors.BLUE}[*] {msg}{Colors.RESET}")


def success(msg: str):
    print(f"{Colors.GREEN}[✓] {msg}{Colors.RESET}")


def warn(msg: str):
    print(f"{Colors.YELLOW}[!] {msg}{Colors.RESET}")


def run_command(cmd: list[str], check: bool = True) -> subprocess.CompletedProcess:
    """Ejecuta un comando interactivo redirigiendo stdout/stderr."""
    return subprocess.run(cmd, check=check)


def update_mirrors():
    log("1/5: Optimizando lista de mirrors (Servidores Globales Oficiales)...")
    try:
        # Extrae los servidores seguros y rápidos directamente de la API de Arch Linux
        cmd = "curl -s 'https://archlinux.org/mirrorlist/?protocol=https&ip_version=4&use_mirror_status=on' | grep -v 'pkgbuild.com' | sed -e 's/^#Server/Server/' | sudo tee /etc/pacman.d/mirrorlist > /dev/null"
        subprocess.run(cmd, shell=True, check=True)
        success("Mirrors actualizados desde la fuente oficial de Arch.")
    except subprocess.CalledProcessError:
        warn("No se pudo contactar con Arch Linux. Se usarán los espejos actuales.")


def update_pacman_aur():
    log("2/5: Actualizando Pacman y AUR...")
    if shutil.which("paru"):
        run_command(["paru", "-Syu"])
    elif shutil.which("yay"):
        run_command(["yay", "-Syu"])
    else:
        run_command(["sudo", "pacman", "-Syu"])
    success("Paquetes nativos actualizados.")


def update_flatpaks():
    if shutil.which("flatpak"):
        log("3/5: Actualizando Flatpaks...")
        run_command(["flatpak", "update", "-y"])
        run_command(["flatpak", "uninstall", "--unused", "-y"])
        success("Flatpaks actualizados y limpios.")
    else:
        warn("Flatpak no está instalado.")


def update_appimages():
    log("4/5: Gestión de AppImages...")
    if shutil.which("appimageupdatetool"):
        warn("Herramienta detectada, pero requiere que indiques la ruta de cada AppImage manualmente.")
    else:
        warn("Tienes AppImages. Recuerda que son ejecutables portables; actualízalos desde su web oficial cuando sea necesario.")


def maintenance():
    log("5/5: Mantenimiento (Huérfanos y Caché)...")
    
    # Huérfanos
    result = subprocess.run(["pacman", "-Qtdq"], capture_output=True, text=True)
    orphans = result.stdout.strip().splitlines()
    if orphans:
        run_command(["sudo", "pacman", "-Rns", *orphans])
        success(f"Eliminados {len(orphans)} paquete(s) huérfano(s).")
    else:
        success("No hay paquetes huérfanos.")
    
    # Caché
    if shutil.which("paccache"):
        run_command(["sudo", "paccache", "-r"])
        run_command(["sudo", "paccache", "-ruk0"])
        success("Caché optimizada (conservadas últimas 3 versiones).")
    else:
        run_command(["sudo", "pacman", "-Sc", "--noconfirm"])
        success("Caché limpiada con pacman.")


def check_kernel_reboot():
    try:
        running_kernel = os.uname().release.split("-")[0]
        result = subprocess.run(["pacman", "-Q", "linux"], capture_output=True, text=True, check=True)
        installed_kernel = result.stdout.strip().split()[1]

        if running_kernel not in installed_kernel:
            print(f"\n{Colors.RED}" + "-" * 50)
            print("[!] El Kernel fue actualizado. Se recomienda reiniciar el sistema.")
            print("-" * 50 + f"{Colors.RESET}")
    except subprocess.CalledProcessError:
        pass


def main():
    try:
        update_mirrors()
        update_pacman_aur()
        update_flatpaks()
        update_appimages()
        maintenance()
        check_kernel_reboot()
        success("¡Actualización total completada con éxito!")
    except subprocess.CalledProcessError as e:
        print(f"\n{Colors.RED}[X] Error al ejecutar un comando.{Colors.RESET}")
        sys.exit(e.returncode)
    except KeyboardInterrupt:
        print(f"\n{Colors.YELLOW}[!] Operación cancelada por el usuario.{Colors.RESET}")
        sys.exit(130)


if __name__ == "__main__":
    main()
