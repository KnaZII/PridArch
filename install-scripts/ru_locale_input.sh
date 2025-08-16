#!/bin/bash
# Configure Russian locale, Hyprland keyboard layouts, and keybind hints

## WARNING: DO NOT EDIT BEYOND THIS LINE IF YOU DON'T KNOW WHAT YOU ARE DOING! ##
SCRIPT_DIR="$( cd "$( dirname "${BASH_SOURCE[0]}" )" && pwd )"

# Change the working directory to the parent directory of the script
PARENT_DIR="$SCRIPT_DIR/.."
cd "$PARENT_DIR" || { echo "${ERROR} Failed to change directory to $PARENT_DIR"; exit 1; }

# Source the global functions script
if ! source "$(dirname "$(readlink -f "$0")")/Global_functions.sh"; then
  echo "Failed to source Global_functions.sh"
  exit 1
fi

# Set the name of the log file to include the current date and time
LOG="Install-Logs/install-$(date +%d-%H%M%S)_ru-locale-input.log"

echo "${NOTE} Applying Russian locale and keyboard settings..." | tee -a "$LOG"

# Ensure ru_RU.UTF-8 and en_US.UTF-8 are enabled and generate locales
if [ -f /etc/locale.gen ]; then
  echo "${INFO} Ensuring locales ru_RU.UTF-8 and en_US.UTF-8 are enabled..." | tee -a "$LOG"
  sudo sed -i 's/^#\s*ru_RU.UTF-8/ru_RU.UTF-8/' /etc/locale.gen
  sudo sed -i 's/^#\s*en_US.UTF-8/en_US.UTF-8/' /etc/locale.gen
  if ! grep -q '^ru_RU.UTF-8' /etc/locale.gen; then echo 'ru_RU.UTF-8 UTF-8' | sudo tee -a /etc/locale.gen >/dev/null; fi
  if ! grep -q '^en_US.UTF-8' /etc/locale.gen; then echo 'en_US.UTF-8 UTF-8' | sudo tee -a /etc/locale.gen >/dev/null; fi
  sudo locale-gen | tee -a "$LOG"
fi

# Set default system language to Russian for main programs
echo "${INFO} Setting system language to ru_RU.UTF-8..." | tee -a "$LOG"
echo 'LANG=ru_RU.UTF-8' | sudo tee /etc/locale.conf >/dev/null

# Also set user-level environment override (non-root shells/DEs)
mkdir -p "$HOME/.config/environment.d"
printf 'LANG=ru_RU.UTF-8\nLC_ALL=\n' > "$HOME/.config/environment.d/10-locale.conf"

# Prepare Hyprland directories
HYPR_DIR="$HOME/.config/hypr"
CONF_D_DIR="$HYPR_DIR/conf.d"
mkdir -p "$CONF_D_DIR"

# Write keyboard layout configuration override
INPUT_CONF="$CONF_D_DIR/99-prid-input.conf"
cat > "$INPUT_CONF" <<'EOF'
input {
    kb_layout = us,ru
    kb_options = grp:alt_shift_toggle
}
EOF
echo "${OK} Wrote Hyprland keyboard config at $INPUT_CONF" | tee -a "$LOG"

# Create Russian keybind hints and launcher script
BIN_DIR="$HOME/.local/bin"
DATA_DIR="$HOME/.local/share/hypr"
mkdir -p "$BIN_DIR" "$DATA_DIR"

HINTS_TXT="$DATA_DIR/hints_ru.txt"
cat > "$HINTS_TXT" <<'EOF'
Подсказки биндов (Hyprland)
— Запуск терминала: SUPER + ENTER
— Меню приложений: SUPER + D
— Закрыть окно: SUPER + Q
— Переключить плавающее окно: SUPER + SPACE
— Снимок экрана: SUPER + SHIFT + S
— Перемещение по рабочим столам: SUPER + [1..9]
— Переместить окно на рабочий стол: SUPER + SHIFT + [1..9]
— Перезапуск Hyprland: SUPER + SHIFT + R
— Блокировка экрана: SUPER + L
— Выход/перезагрузка/выключение: SUPER + X
— Буфер обмена: SUPER + V
— Быстрые настройки/уведомления: SUPER + N
— Показать эту подсказку: SUPER + ?
EOF

HINTS_SH="$BIN_DIR/hypr-hints"
cat > "$HINTS_SH" <<'EOF'
#!/bin/bash
set -e
TXT="$HOME/.local/share/hypr/hints_ru.txt"
if command -v rofi >/dev/null 2>&1; then
  cat "$TXT" | rofi -dmenu -i -p "Подсказки"
elif command -v yad >/dev/null 2>&1; then
  yad --title="Подсказки биндов" --text-info --width=600 --height=500 --filename="$TXT" --button=OK:0
else
  ${XDG_TERMINAL:-kitty} -e sh -lc "less \"$TXT\""
fi
EOF
chmod +x "$HINTS_SH"
echo "${OK} Installed keybind hints at $HINTS_SH (data at $HINTS_TXT)" | tee -a "$LOG"

# Add keybind to launch the hints with SUPER + ? (SUPER+SHIFT+SLASH)
BIND_CONF="$CONF_D_DIR/99-prid-binds.conf"
if ! grep -q 'hypr-hints' "$BIND_CONF" 2>/dev/null; then
  printf 'bind = SUPER_SHIFT, SLASH, exec, %s\n' "$HINTS_SH" >> "$BIND_CONF"
  echo "${OK} Added bind SUPER+? for hints in $BIND_CONF" | tee -a "$LOG"
fi

# Try to ensure main config sources conf.d (best-effort)
MAIN_CONF="$HYPR_DIR/hyprland.conf"
if [ -f "$MAIN_CONF" ] && ! grep -q 'conf.d' "$MAIN_CONF"; then
  echo "${NOTE} Ensuring $MAIN_CONF sources conf.d/*.conf (best-effort)" | tee -a "$LOG"
  printf '\n# Include additional configs\nsource = ~/.config/hypr/conf.d/*.conf\n' >> "$MAIN_CONF"
fi

printf "\n%.0s" {1..1}

