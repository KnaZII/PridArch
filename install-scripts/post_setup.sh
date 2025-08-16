#!/bin/bash
# Post-setup for PridArch: RU layout, optional repo clone, console branding, Waybar hints button (RU)

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

LOG="Install-Logs/install-$(date +%d-%H%M%S)_post-setup.log"

echo "${NOTE} Выполняется пост-настройка PridArch..." | tee -a "$LOG"

HYPR_DIR="$HOME/.config/hypr"
CONF_D_DIR="$HYPR_DIR/conf.d"
mkdir -p "$CONF_D_DIR"

ensure_ru_layout() {
  echo "${INFO} Настройка раскладки клавиатуры Hyprland (us,ru + Alt+Shift)..." | tee -a "$LOG"
  local found_layout_files
  mapfile -t found_layout_files < <(grep -RIl "^[[:space:]]*kb_layout[[:space:]]*=" "$HYPR_DIR" 2>/dev/null || true)

  if [ ${#found_layout_files[@]} -gt 0 ]; then
    for f in "${found_layout_files[@]}"; do
      cp -a "$f" "$f.bak.$(date +%s)" 2>/dev/null || true
      sed -i -E 's/^[[:space:]]*kb_layout[[:space:]]*=.*/    kb_layout = us,ru/' "$f"
      if grep -q "^[[:space:]]*kb_options[[:space:]]*=" "$f"; then
        sed -i -E 's/^[[:space:]]*kb_options[[:space:]]*=.*/    kb_options = grp:alt_shift_toggle/' "$f"
      else
        printf '\n    kb_options = grp:alt_shift_toggle\n' >> "$f"
      fi
      echo "${OK} Обновлён файл: $f" | tee -a "$LOG"
    done
  fi

  local INPUT_CONF="$CONF_D_DIR/99-prid-input.conf"
  if [ ! -f "$INPUT_CONF" ]; then
    cat > "$INPUT_CONF" <<'EOF'
input {
    kb_layout = us,ru
    kb_options = grp:alt_shift_toggle
}
EOF
    echo "${OK} Создано $INPUT_CONF" | tee -a "$LOG"
  fi

  local MAIN_CONF="$HYPR_DIR/hyprland.conf"
  if [ -f "$MAIN_CONF" ] && ! grep -q 'conf.d/\*\.conf' "$MAIN_CONF"; then
    printf '\n# Include additional configs\nsource = ~/.config/hypr/conf.d/*.conf\n' >> "$MAIN_CONF"
    echo "${OK} Добавлено подключение conf.d в $MAIN_CONF" | tee -a "$LOG"
  fi
}

clone_repo_with_consent() {
  local REPO_URL="https://github.com/Sergeydigl3/zapret-discord-youtube-linux.git"
  local TARGET_DIR="$HOME/zapret-discord-youtube-linux"
  if whiptail --title "Клонировать репозиторий?" --yesno "Клонировать в домашнюю папку репозиторий:\n$REPO_URL ?" 10 70; then
    if [ -d "$TARGET_DIR/.git" ]; then
      echo "${NOTE} Репозиторий уже существует. Обновляем..." | tee -a "$LOG"
      git -C "$TARGET_DIR" pull | tee -a "$LOG"
    else
      echo "${INFO} Клонируем репозиторий..." | tee -a "$LOG"
      git clone --depth=1 "$REPO_URL" "$TARGET_DIR" | tee -a "$LOG"
    fi
  else
    echo "${NOTE} Пропущено клонирование репозитория по запросу пользователя." | tee -a "$LOG"
  fi
}

brand_console() {
  echo "${INFO} Добавляем баннер PridArch в консоль (zsh/bash)..." | tee -a "$LOG"
  local banner='\n\033[1;35mPridArch\033[0m\n'
  local block_start="# >>> PridArch banner >>>"
  local block_end="# <<< PridArch banner <<<"
  local snippet="$block_start\nif [ -z \"$PRIDARCH_BANNER_SHOWN\" ]; then\n  export PRIDARCH_BANNER_SHOWN=1\n  printf \"$banner\"\nfi\n$block_end\n"

  for rc in "$HOME/.zshrc" "$HOME/.bashrc"; do
    if [ -f "$rc" ]; then
      if ! grep -q "PridArch banner" "$rc"; then
        printf "\n%s\n" "$snippet" >> "$rc"
        echo "${OK} Баннер добавлен в $rc" | tee -a "$LOG"
      else
        echo "${NOTE} Баннер уже присутствует в $rc" | tee -a "$LOG"
      fi
    else
      printf "%s\n" "$snippet" >> "$rc"
      echo "${OK} Создан $rc и добавлен баннер" | tee -a "$LOG"
    fi
  done
}

waybar_hints_ru() {
  echo "${INFO} Добавляем кнопку подсказок в Waybar (РУС)..." | tee -a "$LOG"
  local WCONF
  for candidate in "$HOME/.config/waybar/config.jsonc" "$HOME/.config/waybar/config.json" "$HOME/.config/waybar/config"; do
    if [ -f "$candidate" ]; then WCONF="$candidate"; break; fi
  done
  if [ -z "$WCONF" ]; then
    echo "${WARN} Конфигурация Waybar не найдена. Пропуск." | tee -a "$LOG"
    return 0
  fi

  cp -a "$WCONF" "$WCONF.bak.$(date +%s)" 2>/dev/null || true

  # 1) Добавить custom/hints в modules-right, если отсутствует
  if ! grep -q 'custom/hints' "$WCONF"; then
    sed -i -E 's/("modules-right"[[:space:]]*:[[:space:]]*\[)[[:space:]]*/\1 "custom\/hints", /' "$WCONF" || true
  fi

  # 2) Добавить объект custom/hints в корень, если отсутствует
  if ! grep -q '"custom/hints"[[:space:]]*:' "$WCONF"; then
    sed -i -E ':a; $!{N; ba}; s/}\s*$/,\n  "custom\/hints": {\n    "format": "ПОДСКАЗКИ",\n    "tooltip": true,\n    "interval": 0,\n    "on-click": "~\/\\.local\/bin\/hypr-hints"\n  }\n}/' "$WCONF"
  fi

  echo "${OK} Кнопка подсказок добавлена в Waybar: $WCONF" | tee -a "$LOG"
}

ensure_ru_layout
clone_repo_with_consent
brand_console
waybar_hints_ru

printf "\n%.0s" {1..1}

