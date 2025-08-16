#!/bin/bash
# https://github.com/JaKooLit

clear

# Print installer banner first
echo "PridArchInstaller"

# Set some colors for output messages
OK="$(tput setaf 2)[OK]$(tput sgr0)"
ERROR="$(tput setaf 1)[ERROR]$(tput sgr0)"
NOTE="$(tput setaf 3)[NOTE]$(tput sgr0)"
INFO="$(tput setaf 4)[INFO]$(tput sgr0)"
WARN="$(tput setaf 1)[WARN]$(tput sgr0)"
CAT="$(tput setaf 6)[ACTION]$(tput sgr0)"
MAGENTA="$(tput setaf 5)"
ORANGE="$(tput setaf 214)"
WARNING="$(tput setaf 1)"
YELLOW="$(tput setaf 3)"
GREEN="$(tput setaf 2)"
BLUE="$(tput setaf 4)"
SKY_BLUE="$(tput setaf 6)"
RESET="$(tput sgr0)"

# Create Directory for Install Logs
if [ ! -d Install-Logs ]; then
    mkdir Install-Logs
fi

# Repository root (folder of this script)
REPO_ROOT="$( cd "$( dirname "${BASH_SOURCE[0]}" )" && pwd )"

# Set the name of the log file to include the current date and time
LOG="Install-Logs/01-Hyprland-Install-Scripts-$(date +%d-%H%M%S).log"

# Check if running as root. If root, script will exit
if [[ $EUID -eq 0 ]]; then
    echo "${ERROR}  This script should ${WARNING}NOT${RESET} be executed as root!! Exiting......." | tee -a "$LOG"
    printf "\n%.0s" {1..2} 
    exit 1
fi

# Check if PulseAudio package is installed
if pacman -Qq | grep -qw '^pulseaudio$'; then
    echo "$ERROR PulseAudio is detected as installed. Uninstall it first or edit install.sh on line 211 (execute_script 'pipewire.sh')." | tee -a "$LOG"
    printf "\n%.0s" {1..2} 
    exit 1
fi

# Check if base-devel is installed
if pacman -Q base-devel &> /dev/null; then
    echo "base-devel is already installed."
else
    echo "$NOTE Install base-devel.........."

    if sudo pacman -S --noconfirm base-devel; then
        echo "👌 ${OK} base-devel has been installed successfully." | tee -a "$LOG"
    else
        echo "❌ $ERROR base-devel not found nor cannot be installed."  | tee -a "$LOG"
        echo "$ACTION Please install base-devel manually before running this script... Exiting" | tee -a "$LOG"
        exit 1
    fi
fi

# install whiptails if detected not installed. Necessary for this version
if ! command -v whiptail >/dev/null; then
    echo "${NOTE} - whiptail is not installed. Installing..." | tee -a "$LOG"
    sudo pacman -S --noconfirm libnewt
    printf "\n%.0s" {1..1}
fi

# Select installation mode
INSTALL_MODE=$(whiptail --title "Режим установки" --radiolist "Выберите режим установки:" 16 70 3 \
    "standard" "Обычная установка (стандартная)" ON \
    "russian" "Установка с русской локалью и раскладкой" OFF \
    "postsetup" "Только пост-настройка RU (без установки пакетов)" OFF \
    3>&1 1>&2 2>&3)

if [ $? -ne 0 ]; then
    echo "❌ ${INFO} Установка отменена пользователем." | tee -a "$LOG"
    exit 0
fi

# In post-setup mode, apply RU settings only and exit
if [[ "$INSTALL_MODE" == "postsetup" ]]; then
    echo "${INFO} Режим: пост-настройка. Будут применены RU локаль/раскладки и брендирование." | tee -a "$LOG"
    # Minimal backup to repository folder
    BACKUP_DIR="$REPO_ROOT/UserConfig-Backups/ArchHyprland_PostSetup_$(date +%Y%m%d_%H%M%S)"
    mkdir -p "$BACKUP_DIR"
    for p in "$HOME/.config/hypr" "$HOME/.config/waybar"; do
        [ -e "$p" ] && cp -a "$p" "$BACKUP_DIR/" 2>/dev/null || true
    done
    chmod +x "$REPO_ROOT/install-scripts/ru_locale_input.sh" "$REPO_ROOT/install-scripts/post_setup.sh" 2>/dev/null || true
    bash "$REPO_ROOT/install-scripts/ru_locale_input.sh"
    bash "$REPO_ROOT/install-scripts/post_setup.sh"
    whiptail --title "Готово" --msgbox "Пост-настройка завершена." 10 50
    exit 0
fi

clear

printf "\n%.0s" {1..2}  
echo -e "\e[35m
	╦╔═┌─┐┌─┐╦    ╦ ╦┬ ┬┌─┐┬─┐┬  ┌─┐┌┐┌┌┬┐
	╠╩╗│ ││ │║    ╠═╣└┬┘├─┘├┬┘│  ├─┤│││ ││ 2025
	╩ ╩└─┘└─┘╩═╝  ╩ ╩ ┴ ┴  ┴└─┴─┘┴ ┴┘└┘─┴┘ Arch Linux
\e[0m"
printf "\n%.0s" {1..1} 

# Welcome message using whiptail (for displaying information)
whiptail --title "PridArch Установщик" \
    --msgbox "Добро пожаловать в установщик PridArch!\n\nМы установим и настроим всё за вас!\n\nВ случае конфликтов бэкап системы останется в папке с нашим пакетом, удачи!" \
    14 80

# Ask if the user wants to proceed
if ! whiptail --title "Продолжить установку?" \
    --yesno "Режим: ${INSTALL_MODE}\n\nПродолжить установку?" 8 50; then
    echo -e "\n"
    echo "❌ ${INFO} Вы выбрали ${YELLOW}НЕ ПРОДОЛЖАТЬ${RESET}. ${YELLOW}Выход...${RESET}" | tee -a "$LOG"
    echo -e "\n" 
    exit 1
fi

echo "👌 ${OK} ${SKY_BLUE}Продолжаем установку PridArch...${RESET}" | tee -a "$LOG"

sleep 1
printf "\n%.0s" {1..1}

# install pciutils if detected not installed. Necessary for detecting GPU
if ! pacman -Qs pciutils > /dev/null; then
    echo "${NOTE} - pciutils is not installed. Installing..." | tee -a "$LOG"
    sudo pacman -S --noconfirm pciutils
    printf "\n%.0s" {1..1}
fi

# Path to the install-scripts directory
script_directory=install-scripts

# Function to execute a script if it exists and make it executable
execute_script() {
    local script="$1"
    local script_path="$script_directory/$script"
    if [ -f "$script_path" ]; then
        chmod +x "$script_path"
        if [ -x "$script_path" ]; then
            bash "$script_path"
        else
            echo "Failed to make script '$script' executable."
        fi
    else
        echo "Script '$script' not found in '$script_directory'."
    fi
}

# Backup existing user configs to avoid conflicts with other packages
backup_existing_configs() {
    backup_root="$REPO_ROOT/UserConfig-Backups/ArchHyprland_Backup_$(date +%Y%m%d_%H%M%S)"
    mkdir -p "$backup_root"
    paths_to_backup=(
        "$HOME/.config/hypr"
        "$HOME/.config/waybar"
        "$HOME/.config/rofi"
        "$HOME/.config/wlogout"
        "$HOME/.config/swaync"
        "$HOME/.config/kitty"
        "$HOME/.config/fastfetch"
    )
    echo "${NOTE} Backing up existing configs (if any) to $backup_root" | tee -a "$LOG"
    for p in "${paths_to_backup[@]}"; do
        if [ -e "$p" ]; then
            base_name=$(basename "$p")
            dest="$backup_root/$base_name"
            if cp -a "$p" "$dest" 2>/dev/null; then
                echo "${OK} Backed up $p -> $dest" | tee -a "$LOG"
            fi
        fi
    done
}


## Default values for the options (will be overwritten by preset file if available)
gtk_themes="OFF"
bluetooth="OFF"
thunar="OFF"
quickshell="OFF"
sddm="OFF"
sddm_theme="OFF"
xdph="OFF"
zsh="OFF"
pokemon="OFF"
rog="OFF"
dots="OFF"
input_group="OFF"
nvidia="OFF"
nouveau="OFF"

# Function to load preset file
load_preset() {
    if [ -f "$1" ]; then
        echo "✅ Loading preset: $1"
        source "$1"
    else
        echo "⚠️ Preset file not found: $1. Using default values."
    fi
}

# Check if --preset argument is passed
if [[ "$1" == "--preset" && -n "$2" ]]; then
    load_preset "$2"
fi

# Check if yay or paru is installed
echo "${INFO} - Checking if yay or paru is installed"
if ! command -v yay &>/dev/null && ! command -v paru &>/dev/null; then
    echo "${CAT} - Ни yay, ни paru не найдены. Предложим выбрать..."
    while true; do
        aur_helper=$(whiptail --title "Не установлен yay или paru" --checklist "Выберите один AUR-помощник.\n\nПРИМЕЧАНИЕ: Выберите ровно одного помощника!\nИНФО: пробел — выбрать" 12 60 2 \
            "yay" "AUR-помощник yay" "OFF" \
            "paru" "AUR-помощник paru" "OFF" \
            3>&1 1>&2 2>&3)

        if [ $? -ne 0 ]; then  
            echo "❌ ${INFO} Вы отменили выбор. ${YELLOW}До свидания!${RESET}" | tee -a "$LOG"
            exit 0 
        fi

        if [ -z "$aur_helper" ]; then
            whiptail --title "Ошибка" --msgbox "Нужно выбрать хотя бы одного AUR-помощника для продолжения." 10 60 2
            continue 
        fi

        echo "${INFO} - Вы выбрали: $aur_helper в качестве AUR-помощника"  | tee -a "$LOG"

        aur_helper=$(echo "$aur_helper" | tr -d '"')

        # Check if multiple helpers were selected
        if [[ $(echo "$aur_helper" | wc -w) -ne 1 ]]; then
            whiptail --title "Ошибка" --msgbox "Нужно выбрать ровно одного AUR-помощника." 10 60 2
            continue  
        else
            break 
        fi
    done
else
    echo "${NOTE} - AUR-помощник уже установлен. Пропускаем выбор."
fi

# List of services to check for active login managers
services=("gdm.service" "gdm3.service" "lightdm.service" "lxdm.service")

# Function to check if any login services are active
check_services_running() {
    active_services=()  # Array to store active services
    for svc in "${services[@]}"; do
        if systemctl is-active --quiet "$svc"; then
            active_services+=("$svc")  
        fi
    done

    if [ ${#active_services[@]} -gt 0 ]; then
        return 0  
    else
        return 1  
    fi
}

if check_services_running; then
    active_list=$(printf "%s\n" "${active_services[@]}")

    # Display the active login manager(s) in the whiptail message box
    whiptail --title "Обнаружены активные менеджеры входа (не SDDM)" \
        --msgbox "Обнаружены активные менеджеры входа:\n\n$active_list\n\nЕсли хотите установить SDDM и тему SDDM, остановите и отключите эти сервисы, затем перезагрузитесь перед запуском скрипта.\n\nОпция установки SDDM и темы SDDM временно недоступна." 20 80
fi

# Check if NVIDIA GPU is detected
nvidia_detected=false
if lspci | grep -i "nvidia" &> /dev/null; then
    nvidia_detected=true
    whiptail --title "Обнаружена видеокарта NVIDIA" --msgbox "В системе обнаружена NVIDIA GPU.\n\nПримечание: при выборе соответствующей опции будут установлены nvidia-dkms, nvidia-utils и nvidia-settings." 12 60
fi

# Initialize the options array for whiptail checklist
options_command=(
    whiptail --title "Select Options" --checklist "Choose options to install or configure\nNOTE: 'SPACEBAR' to select & 'TAB' key to change selection" 28 85 20
)

# Add NVIDIA options if detected
if [ "$nvidia_detected" == "true" ]; then
    options_command+=(
        "nvidia" "Do you want script to configure NVIDIA GPU?" "OFF"
        "nouveau" "Do you want Nouveau to be blacklisted?" "OFF"
    )
fi

# Add 'input_group' option if user is not in input group
input_group_detected=false
if ! groups "$(whoami)" | grep -q '\binput\b'; then
    input_group_detected=true
    whiptail --title "Группа input" --msgbox "Вы сейчас не состоите в группе input.\n\nДобавление в эту группу может быть нужно для корректной работы индикатора раскладки Waybar." 12 60
fi

# Add 'input_group' option if necessary
if [ "$input_group_detected" == "true" ]; then
    options_command+=(
        "input_group" "Add your USER to input group for some waybar functionality?" "OFF"
    )
fi

# Conditionally add SDDM and SDDM theme options if no active login manager is found
if ! check_services_running; then
    options_command+=(
        "sddm" "Установить и настроить менеджер входа SDDM?" "OFF"
        "sddm_theme" "Скачать и установить дополнительную тему SDDM?" "OFF"
    )
fi

# Add the remaining static options
options_command+=(
    "gtk_themes" "Установить GTK темы? (для функций Светлая/Тёмная)" "OFF"
    "bluetooth" "Настроить Bluetooth?" "OFF"
    "thunar" "Установить файловый менеджер Thunar?" "OFF"
    "quickshell" "Установить quickshell для обзора рабочего стола?" "OFF"
    "xdph" "Установить XDG-DESKTOP-PORTAL-HYPRLAND (шэринг экрана)?" "OFF"
    "zsh" "Установить zsh и Oh-My-Zsh?" "OFF"
    "pokemon" "Добавить Pokemon color scripts в терминал?" "OFF"
    "rog" "Настройка для ноутбуков Asus ROG?" "OFF"
    "dots" "Скачать и установить преднастроенные Hyprland dotfiles?" "OFF"
)

# Capture the selected options before the while loop starts
while true; do
    selected_options=$("${options_command[@]}" 3>&1 1>&2 2>&3)

    # Check if the user pressed Cancel (exit status 1)
    if [ $? -ne 0 ]; then
        echo -e "\n"
        echo "❌ ${INFO} You 🫵 cancelled the selection. ${YELLOW}Goodbye!${RESET}" | tee -a "$LOG"
        exit 0  # Exit the script if Cancel is pressed
    fi

    # If no option was selected, notify and restart the selection
    if [ -z "$selected_options" ]; then
        whiptail --title "Предупреждение" --msgbox "Ни одна опция не выбрана. Пожалуйста, выберите хотя бы одну опцию." 10 60
        continue  # Return to selection if no options selected
    fi

    # Strip the quotes and trim spaces if necessary (sanitize the input)
    selected_options=$(echo "$selected_options" | tr -d '"' | tr -s ' ')

    # Convert selected options into an array (preserving spaces in values)
    IFS=' ' read -r -a options <<< "$selected_options"

    # Check if the "dots" option was selected
    dots_selected="OFF"
    for option in "${options[@]}"; do
        if [[ "$option" == "dots" ]]; then
            dots_selected="ON"
            break
        fi
    done

    # If "dots" is not selected, show a note and ask the user to proceed or return to choices
    if [[ "$dots_selected" == "OFF" ]]; then
        # Show a note about not selecting the "dots" option
        if ! whiptail --title "Dotfiles Hyprland" --yesno \
        "Вы не выбрали установку преднастроенных Hyprland dotfiles.\n\nЕсли продолжите без dotfiles, Hyprland запустится с базовой конфигурацией по умолчанию.\n\nПродолжить без dotfiles или вернуться к выбору опций?" \
        --yes-button "Продолжить" --no-button "Вернуться" 13 90; then
            echo "🔙 Возврат к опциям..." | tee -a "$LOG"
            continue
        else
            # User chose to continue
            echo "${INFO} ⚠️ Продолжаем БЕЗ установки dotfiles..." | tee -a "$LOG"
			printf "\n%.0s" {1..1}
        fi
    fi

    # Prepare the confirmation message
    confirm_message="Вы выбрали следующие опции:\n\n"
    for option in "${options[@]}"; do
        confirm_message+=" - $option\n"
    done
    confirm_message+="\nПодтвердить выбор?"

    # Confirmation prompt
    if ! whiptail --title "Подтверждение выбора" --yesno "$(printf "%s" "$confirm_message")" 25 80; then
        echo -e "\n"
        echo "❌ ${SKY_BLUE}Возврат к опциям...${RESET}" | tee -a "$LOG"
        continue 
    fi

    echo "👌 ${OK} Вы подтвердили выбор. Продолжаем установку ${SKY_BLUE}Hyprland...${RESET}" | tee -a "$LOG"
    break  
done

printf "\n%.0s" {1..1}

# Ensuring base-devel is installed
execute_script "00-base.sh"
sleep 1
execute_script "pacman.sh"
sleep 1

# Execute AUR helper script after other installations if applicable
if [ "$aur_helper" == "paru" ]; then
    execute_script "paru.sh"
elif [ "$aur_helper" == "yay" ]; then
    execute_script "yay.sh"
fi

sleep 1

# Backup existing configs before install to avoid conflicts
backup_existing_configs

# Run the Hyprland related scripts
echo "${INFO} Устанавливаем ${SKY_BLUE}дополнительные пакеты Hyprland...${RESET}" | tee -a "$LOG"
sleep 1
execute_script "01-hypr-pkgs.sh"

echo "${INFO} Устанавливаем ${SKY_BLUE}pipewire и pipewire-audio...${RESET}" | tee -a "$LOG"
sleep 1
execute_script "pipewire.sh"

echo "${INFO} Устанавливаем ${SKY_BLUE}необходимые шрифты...${RESET}" | tee -a "$LOG"
sleep 1
execute_script "fonts.sh"

echo "${INFO} Устанавливаем ${SKY_BLUE}Hyprland...${RESET}"
sleep 1
execute_script "hyprland.sh"

# Clean up the selected options (remove quotes and trim spaces)
selected_options=$(echo "$selected_options" | tr -d '"' | tr -s ' ')

# Convert selected options into an array (splitting by spaces)
IFS=' ' read -r -a options <<< "$selected_options"

# Loop through selected options
for option in "${options[@]}"; do
    case "$option" in
        sddm)
            if check_services_running; then
                active_list=$(printf "%s\n" "${active_services[@]}")
                whiptail --title "Ошибка" --msgbox "Один из следующих менеджеров входа запущен:\n$active_list\n\nОстановите и отключите его или не выбирайте SDDM." 12 60
                exec "$0"  
            else
                echo "${INFO} Устанавливаем и настраиваем ${SKY_BLUE}SDDM...${RESET}" | tee -a "$LOG"
                execute_script "sddm.sh"
            fi
            ;;
        nvidia)
            echo "${INFO} Настраиваем ${SKY_BLUE}NVIDIA${RESET}" | tee -a "$LOG"
            execute_script "nvidia.sh"
            ;;
        nouveau)
            echo "${INFO} Блокируем драйвер ${SKY_BLUE}nouveau${RESET}"
            execute_script "nvidia_nouveau.sh" | tee -a "$LOG"
            ;;
        gtk_themes)
            echo "${INFO} Устанавливаем ${SKY_BLUE}GTK темы...${RESET}" | tee -a "$LOG"
            execute_script "gtk_themes.sh"
            ;;
        input_group)
            echo "${INFO} Добавляем пользователя в группу ${SKY_BLUE}input...${RESET}" | tee -a "$LOG"
            execute_script "InputGroup.sh"
            ;;
        quickshell)
            echo "${INFO} Устанавливаем ${SKY_BLUE}quickshell (обзор рабочего стола)...${RESET}" | tee -a "$LOG"
            execute_script "quickshell.sh"
            ;;
        xdph)
            echo "${INFO} Устанавливаем ${SKY_BLUE}xdg-desktop-portal-hyprland...${RESET}" | tee -a "$LOG"
            execute_script "xdph.sh"
            ;;
        bluetooth)
            echo "${INFO} Настраиваем ${SKY_BLUE}Bluetooth...${RESET}" | tee -a "$LOG"
            execute_script "bluetooth.sh"
            ;;
        thunar)
            echo "${INFO} Устанавливаем файловый менеджер ${SKY_BLUE}Thunar...${RESET}" | tee -a "$LOG"
            execute_script "thunar.sh"
            execute_script "thunar_default.sh"
            ;;
        sddm_theme)
            echo "${INFO} Скачиваем и устанавливаем ${SKY_BLUE}дополнительную тему SDDM...${RESET}" | tee -a "$LOG"
            execute_script "sddm_theme.sh"
            ;;
        zsh)
            echo "${INFO} Устанавливаем ${SKY_BLUE}zsh с Oh-My-Zsh...${RESET}" | tee -a "$LOG"
            execute_script "zsh.sh"
            ;;
        pokemon)
            echo "${INFO} Добавляем ${SKY_BLUE}Pokemon color scripts${RESET} в терминал..." | tee -a "$LOG"
            execute_script "zsh_pokemon.sh"
            ;;
        rog)
            echo "${INFO} Устанавливаем пакеты для ноутбуков ${SKY_BLUE}ROG...${RESET}" | tee -a "$LOG"
            execute_script "rog.sh"
            ;;
        dots)
            echo "${INFO} Устанавливаем преднастроенные ${SKY_BLUE}Hyprland dotfiles...${RESET}" | tee -a "$LOG"
            execute_script "dotfiles-main.sh"
            ;;
        *)
            echo "Unknown option: $option" | tee -a "$LOG"
            ;;
    esac
done

if [[ "$INSTALL_MODE" == "russian" ]]; then
    # Apply Russian locale, keyboard layouts, and keybind hints
    echo "${INFO} Применяем ${SKY_BLUE}русскую локаль, RU/US раскладки и бинд подсказок...${RESET}" | tee -a "$LOG"
    execute_script "ru_locale_input.sh"
fi

# Post-setup adjustments (common)
echo "${INFO} Выполняем ${SKY_BLUE}пост-настройку PridArch${RESET}" | tee -a "$LOG"
execute_script "post_setup.sh"

sleep 1
# copy fastfetch config if arch.png is not present
if [ ! -f "$HOME/.config/fastfetch/arch.png" ]; then
    cp -r assets/fastfetch "$HOME/.config/"
fi

clear

# final check essential packages if it is installed
execute_script "02-Final-Check.sh"

printf "\n%.0s" {1..1}

# Check if hyprland or hyprland-git is installed
if pacman -Q hyprland &> /dev/null || pacman -Q hyprland-git &> /dev/null; then
    printf "\n ${OK} 👌 Hyprland установлен. Некоторые необходимые пакеты могут отсутствовать — смотрите выше!"
    printf "\n${CAT} Игнорируйте это сообщение, если выше указано, что ${YELLOW}все необходимые пакеты${RESET} установлены.\n"
    sleep 2
    printf "\n%.0s" {1..2}

    printf "${SKY_BLUE}Спасибо${RESET} за использование ${MAGENTA}Hyprland Dots${RESET}. ${YELLOW}Хорошего дня!${RESET}"
    printf "\n%.0s" {1..2}

    printf "\n${NOTE} Запустить Hyprland можно командой ${SKY_BLUE}Hyprland${RESET} (если SDDM не установлен).\n"
    printf "\n${NOTE} ${YELLOW}Настоятельно рекомендуется перезагрузить${RESET} систему.\n\n"

    while true; do
        echo -n "${CAT} Перезагрузить сейчас? (y/n): "
        read HYP
        HYP=$(echo "$HYP" | tr '[:upper:]' '[:lower:]')

        if [[ "$HYP" == "y" || "$HYP" == "yes" ]]; then
            echo "${INFO} Перезагрузка..."
            systemctl reboot 
            break
        elif [[ "$HYP" == "n" || "$HYP" == "no" ]]; then
            echo "👌 ${OK} Вы выбрали не перезагружаться сейчас"
            printf "\n%.0s" {1..1}
            # Check if NVIDIA GPU is present
            if lspci | grep -i "nvidia" &> /dev/null; then
                echo "${INFO} Обнаружена ${YELLOW}NVIDIA GPU${RESET}. Напоминание: требуется перезагрузка системы..."
                printf "\n%.0s" {1..1}
            fi
            break
        else
            echo "${WARN} Неверный ответ. Введите 'y' или 'n'."
        fi
    done
else
    # Print error message if neither package is installed
    printf "\n${WARN} Hyprland НЕ установлен. Проверьте 00_CHECK-time_installed.log и другие файлы в директории Install-Logs/."
    printf "\n%.0s" {1..3}
    exit 1
fi


printf "\n%.0s" {1..2}