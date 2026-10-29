# MyDotfiles

**A personal Arch Linux workspace, built around Niri.**

Configuration for a scrolling Wayland desktop with Noctalia, Kitty and Zsh, plus everyday shell utilities and development tooling.

[Español — configuración y atajos](README.es.md) · [Niri configuration](config.kdl) · [Installer source](install.sh)

## What's inside

| Layer | Files |
| --- | --- |
| Desktop | `config.kdl`, `noctalia/`, `rofi/` |
| Terminal and shell | `kitty/`, `zsh/`, `fastfetch/` |
| Appearance | `gtk/`, `Kvantum/`, `wallpapers/` |
| Utilities | `scripts/` |
| Development | `opencode/`, `pnpm/`, `vscode/` |

## Inspect, then adapt

```bash
git clone https://github.com/Logaric01000001/MyDotfiles.git
cd MyDotfiles
less install.sh
less config.kdl
```

This is a personal setup, not a distribution or a universal installer. Start by copying only the files you understand and need. Adjust display names, keybindings, application paths and preferences for your machine.

The optional `./install.sh` bootstrap has broad effects: it installs Pacman/AUR packages, copies user configuration and utilities, and can configure system services and the login environment. It creates timestamped backups for changed, existing non-symlink files it handles; this is **not** a complete system rollback. Review the whole script and make your own backup before running it. AUR package availability is external to this repository.

## Desktop entry points

The documented bindings use **Super** as Mod: `Super+Return` opens Kitty, `Super+D` opens Rofi, and `Super+Shift+H` opens the shortcut menu. See the [full Spanish shortcut table](README.es.md#atajos-mod--superwindows) and `config.kdl` for the source of truth.

No desktop screenshot is included yet. Wallpaper files alone do not demonstrate a running desktop.

## Contributions

Small portability fixes and clear bug reports are useful. Include the affected file, expected behavior and a minimal reproduction. Remove usernames, hostnames, credentials and network identifiers from logs. Do not add personal tokens or private configurations.

No repository-level license was present during this documentation update. Do not assume unrestricted reuse; individual components may have their own terms.
