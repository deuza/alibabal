#!/bin/bash
# Version : 0.2-dev

start_time=$(date +%s%N)
total_sent=0

# Couleurs
green='\033[1;32m'
cyan='\033[1;36m'
red='\033[1;31m'
reset='\033[0m'

# Valeurs par défaut
delay=0.5
timeout=5
count="$1"

# Help
if [ "$1" = "--help" ]; then
    echo "Usage: $0 [nombre] [délai]"
    echo "  nombre : nombre de hassanats à envoyer (par défaut infini)"
    echo "  délai  : délai entre chaque envoi en secondes (par défaut 0.5)"
    exit 0
fi

if [ -n "$2" ]; then
    delay="$2"
fi

cleanup() {
    end_time=$(date +%s%N)
    elapsed=$((end_time - start_time))
    seconds=$((elapsed / 1000000000))
    millis=$(( (elapsed / 1000000) % 1000 ))

    echo -e "\n${red}[!] Mission terminée !${reset}"
    echo -e "${cyan}[!] 🦁 Total hassanats envoyées au Lion de Roubaix 🦁 : ${total_sent}${reset}"
    echo -e "${cyan}[!] Temps total écoulé : ${elapsed} ns (${seconds}s ${millis}ms)${reset}"

    rm -f "$pipe_in" "$pipe_out"
    if kill -0 "$wscat_pid" 2>/dev/null; then
        kill "$wscat_pid"
    fi
    exit 0
}

trap cleanup INT TERM EXIT

# Vérifie si $count est un entier positif
if [ -n "$count" ]; then
    if ! echo "$count" | grep -Eq '^[0-9]+$'; then
        echo "Erreur: l'argument doit être un entier positif." >&2
        exit 1
    fi
fi

# Crée les FIFOs avec mktemp
pipe_in=$(mktemp -u /tmp/wscatpipe_in.XXXXXX)
pipe_out=$(mktemp -u /tmp/wscatpipe_out.XXXXXX)
mkfifo "$pipe_in" "$pipe_out"

# Lance wscat connecté aux deux pipes
wscat -c wss://data.alibabal.fr/ws/ < "$pipe_in" > "$pipe_out" &
wscat_pid=$!
sleep 1

i=1
exec 3> "$pipe_in"
exec 4< "$pipe_out"

while [ -z "$count" ] || [ "$i" -le "$count" ]; do
    timestamp=$(date +"[%H:%M:%S]")

    echo '{"action":"add"}' >&3
    total_sent=$((total_sent + 1))
    echo -e "${timestamp} 🕌 ${green}[+] Hassanat envoyée #$i${reset}"

    if read -t "$timeout" -u 4 line; then
        echo -e "${timestamp} 🦁 ${cyan}[<] Réponse reçue : $line${reset}"
    else
        echo -e "${timestamp} ${red}[!] Timeout sans réponse après envoi #$i${reset}"
    fi

    sleep "$delay"
    i=$((i+1))
done

exec 3>&-
exec 4<&-
sleep 1

