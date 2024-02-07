#!/bin/bash

set -euo pipefail

###############################
# Prompts
###############################
# needs: whiptail

function prompt_kernels() {
    set -euo pipefail
    declare chosen_kernels
    chosen_kernels=$(whiptail --notags --checklist "Choose kernel(s) to install:" $WHIPTAIL_HEIGHT $WHIPTAIL_WIDTH $WHIPTAIL_LIST_HEIGHT \
        "linux" "Latest stable linux kernel" ON \
        "linux-lts" "Long-term support linux kernel" OFF \
        "linux-hardened" "Hardened linux kernel" OFF \
        "linux-zen" "Zen linux kernel" OFF 3>&1 1>&2 2>&3)
    echo "$chosen_kernels"
}

function prompt_username() {
    set -euo pipefail
    declare username
    username=$(whiptail --inputbox "Please provide a username for the new user:" $WHIPTAIL_HEIGHT $WHIPTAIL_WIDTH 3>&1 1>&2 2>&3)
    echo "$username"
}

function prompt_password() {
    set -euo pipefail
    declare user_password
    user_password=$(whiptail --passwordbox "Please provide a password for the new user:" $WHIPTAIL_HEIGHT $WHIPTAIL_WIDTH 3>&1 1>&2 2>&3)
    echo "$user_password"
}

function prompt_hostname() {
    set -euo pipefail
    declare hostname
    hostname=$(whiptail --inputbox "Please provide a hostname for the new system:" $WHIPTAIL_HEIGHT $WHIPTAIL_WIDTH 3>&1 1>&2 2>&3)
    echo "$hostname"
}
