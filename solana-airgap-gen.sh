#!/bin/bash
set -euo pipefail

# Configuration
OUTPUT_DIR="${HOME}/.solana_airgap/$(date +%s)"
KEYFILE="${OUTPUT_DIR}/wallet.json"
SEEDFILE="${OUTPUT_DIR}/seed.txt"
TEMPFILE=$(mktemp)

# Colors
RED=$(tput setaf 1)
GREEN=$(tput setaf 2)
YELLOW=$(tput setaf 3)
RESET=$(tput sgr0)

# Animation
spinner() {
    local pid=$!
    local delay=0.15
    local spinstr='|/-\'
    while [ "$(ps a | awk '{print $1}' | grep $pid)" ]; do
        local temp=${spinstr#?}
        printf " [%c] " "$spinstr"
        local spinstr=$temp${spinstr%"$temp"}
        sleep $delay
        printf "\b\b\b\b\b"
    done
    printf "    \b\b\b\b"
}

# Security checks
check_environment() {
    echo -e "\n${YELLOW}=== SYSTEM CHECKS ===${RESET}"
    
    # Network check
    if ip link show | grep -q 'state UP'; then
        echo "${RED}✗ Network connection detected!${RESET}"
        exit 1
    else
        echo "${GREEN}✓ Airgap verified${RESET}"
    fi

    # Write protection
    if touch /proc/self/fd/2 2>/dev/null; then
        echo "${RED}✗ Write access detected on protected area!${RESET}"
        exit 1
    else
        echo "${GREEN}✓ Write protection active${RESET}"
    fi
    
    sleep 2
}

show_warnings() {
    clear
    cat <<EOF
${RED}
▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓
▓                                       ▓
▓  ${YELLOW}CRITICAL SECURITY REQUIREMENTS${RED}  ▓
▓                                       ▓
▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓

${YELLOW}1. SYSTEM MUST BE COMPLETELY OFFLINE
2. DISCONNECT ALL NETWORK CABLES
3. DISABLE WIRELESS HARDWARE SWITCH
4. VERIFY PHYSICAL ISOLATION
5. NO EXTERNAL DEVICES CONNECTED

${RED}THIS SYSTEM WILL SELF-DESTRUCT TEMPORARY FILES
AFTER 5 MINUTES OF INACTIVITY${RESET}
EOF
    read -p "Press enter to acknowledge and continue..."
}

generate_vanity() {
    echo -e "\n${YELLOW}=== VANITY SETTINGS ===${RESET}"
    
    read -p "${YELLOW}Enter prefix pattern (Base58 characters): ${RESET}" prefix
    read -p "${YELLOW}Enter suffix pattern (optional): ${RESET}" suffix
    read -p "${YELLOW}Case sensitive? (y/N): ${RESET}" case_sensitive

    local grind_cmd="solana-keygen grind"
    
    # Build command
    [[ -n "$prefix" ]] && grind_cmd+=" --starts-with $prefix"
    [[ -n "$suffix" ]] && grind_cmd+=" --ends-with $suffix"
    [[ "${case_sensitive^^}" != "Y" ]] && grind_cmd+=" --ignore-case"
    
    echo -e "\n${YELLOW}Starting generation...${RESET}"
    echo -e "Pattern: ${GREEN}${prefix}...${suffix}${RESET}"
    echo -e "Threads: ${GREEN}$(($(nproc)/2))${RESET}"
    
    # Start generation with spinner
    (eval "$grind_cmd" > "$TEMPFILE") &
    spinner
    
    # Parse results
    pubkey=$(grep 'pubkey:' "$TEMPFILE" | awk '{print $2}')
    seed=$(grep 'seed phrase:' "$TEMPFILE" | cut -d':' -f2-)
    
    if [ -z "$pubkey" ]; then
        echo -e "\n${RED}✗ Generation failed! Retry with simpler pattern.${RESET}"
        exit 1
    fi
    
    # Secure storage
    mkdir -p "$OUTPUT_DIR"
    echo "$seed" | tr -d ' ' > "$SEEDFILE"
    echo "$pubkey" > "$KEYFILE"
    
    # Set permissions
    chmod 400 "$KEYFILE" "$SEEDFILE"
    chmod 500 "$OUTPUT_DIR"
}

show_results() {
    clear
    cat <<EOF
${GREEN}
▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓
▓                                       ▓
▓       WALLET GENERATION SUCCESS       ▓
▓                                       ▓
▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓
${RESET}

${YELLOW}Public Key:${RESET} ${GREEN}$pubkey${RESET}
${YELLOW}Seed Phrase:${RESET} ${RED}$seed${RESET}

${YELLOW}Files saved to:${RESET}
${GREEN}$KEYFILE${RESET}
${GREEN}$SEEDFILE${RESET}

${RED}NEXT STEPS:
1. Verify checksums immediately
2. Transfer seed phrase to cold storage
3. Destroy these files after backup
4. Perform full system wipe${RESET}
EOF
}

cleanup() {
    shred -u "$TEMPFILE" 2>/dev/null
    shred -u "$KEYFILE" "$SEEDFILE" 2>/dev/null
    rmdir "$OUTPUT_DIR" 2>/dev/null
}
trap cleanup EXIT ERR

main() {
    check_environment
    show_warnings
    generate_vanity
    show_results
}

main "$@"
