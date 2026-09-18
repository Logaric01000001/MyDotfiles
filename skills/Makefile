# ==============================================================================
# Makefile: Antigravity Community Skills Installer
# ==============================================================================

SHELL := /usr/bin/env bash
SCRIPT := ./install-antigravity-skills.sh

.PHONY: all help menu install status dry-run update scan list uninstall uninstall-all test

all: menu

menu:
	@bash $(SCRIPT) --menu

status:
	@bash $(SCRIPT) --status

install:
	@bash $(SCRIPT)

dry-run:
	@bash $(SCRIPT) --dry-run

update:
	@bash $(SCRIPT) --update

scan:
	@bash $(SCRIPT) --security-scan

list:
	@bash $(SCRIPT) --list

uninstall:
	@if [ -z "$(SKILL)" ]; then \
		echo "Error: Debes especificar la Skill a desinstalar. Ejemplo: make uninstall SKILL=playwright-skill"; \
		exit 1; \
	fi
	@bash $(SCRIPT) --uninstall "$(SKILL)"

uninstall-all:
	@bash $(SCRIPT) --uninstall-all

test:
	@echo "Validando sintaxis de bash..."
	@bash -n $(SCRIPT)
	@echo "Sintaxis correcta."

help:
	@echo "=================================================="
	@echo " Antigravity Community Skills Installer"
	@echo "=================================================="
	@echo " Comandos disponibles:"
	@echo "   make                       - Abre el menú interactivo fácil"
	@echo "   make menu                  - Abre el menú interactivo fácil"
	@echo "   make status                - Muestra qué Skills tienes instaladas"
	@echo "   make install               - Instala las 42 Skills curadas"
	@echo "   make update                - Actualiza repositorios e instala novedades"
	@echo "   make uninstall-all         - Desinstala TODAS las Skills con backup"
	@echo "   make uninstall SKILL=<nom> - Desinstala una Skill específica"
	@echo "   make dry-run               - Simula la instalación sin cambios"
	@echo "   make scan                  - Audita seguridad en todos los repos"
	@echo "   make list                  - Lista el catálogo completo de Skills"
	@echo "=================================================="
