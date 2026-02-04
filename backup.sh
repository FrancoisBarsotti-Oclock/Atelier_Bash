#!/usr/bin/env bash
# backup.sh
# Objectif : créer une sauvegarde fiable (archive .tar.gz) d’un répertoire donné,
# en la nommant avec la date/heure, et en la stockant dans /backup (créer si besoin).

set -euo pipefail

# Dossier de destination demandé
BACKUP_DIR="/f/Atelier/Scripts"

LOG_FILE="/var/log/backup.log"

# Initialisation du fichier de log (fallback si /var/log non accessible)
init_log() {
    if mkdir -p "$(dirname "$LOG_FILE")" 2>/dev/null && touch "$LOG_FILE" 2>/dev/null; then
    : # OK, on garde /var/log/backup.log
  else
    LOG_FILE="${BACKUP_DIR}/backup.log"
    mkdir -p "$(dirname "$LOG_FILE")" 2>/dev/null || true
    touch "$LOG_FILE" 2>/dev/null || true
  fi
}
log_line() {
  # $1 = niveau (INFO/ERROR), $2 = message
  printf '%s [%s] %s\n' "$(date +%Y-%m-%d_%H:%M:%S)" "$1" "$2" >> "$LOG_FILE" 2>/dev/null || true
}

# ---- Fonctions utilitaires ----
show_help() {
  cat <<'EOF'
Usage:
  ./backup.sh [OPTIONS] <repertoire_a_sauvegarder>

Options:
  -h, --help   Affiche cette aide

Description:
  - Prend en argument le répertoire à sauvegarder
  - Crée une archive tar.gz
  - Nom : backup_YYYYMMDD_HHMMSS.tar.gz
  - Stocke l'archive dans /backup (créé si absent)
  - Affiche un message de confirmation + la taille de l'archive

Exemples (Git Bash Windows):
  ./backup.sh "/f/ScriptsChallenge"
  ./backup.sh "/c/Users/franc/Documents"
EOF
}

error_exit() {
  echo "❌ Erreur : $*" >&2
  exit 1
}

# ---- Aide (-h / --help) ----
if [[ "${1:-}" == "-h" || "${1:-}" == "--help" ]]; then
  show_help
  exit 0
fi

# ---- Validation des arguments ----
if (( $# != 1 )); # on établit le nombre d'arguments (dans ce cas ce n'est qu'un seul).
then 
  show_help >&2
  echo "1 argument requis : $0 <repertoire_a_sauvegarder>"
  exit 1
fi

# ---- Variables de base définies ----
SOURCE="$1"                             # Répertoire à sauvegarder
DATE="$(date +%Y%m%d_%H%M%S)"            # String pour date actuelle, format demandé 
FOLDER_NAME="$(basename "$SOURCE")"      # Nom du dossier à sauvegarder
ARCHIVE_NAME="backup_${DATE}.tar.gz"     # Format demandé : backup_YYYYMMDD_HHMMSS.tar.gz

# --- Init log ---
init_log
log_line "INFO" "Début sauvegarde | source=$SOURCE | dest=$BACKUP_DIR | archive=$ARCHIVE_NAME"

# ---- Vérification du répertoire source + permissions ----
[[ -e "$SOURCE" ]] || error_exit "Le chemin n'existe pas : $SOURCE"
[[ -d "$SOURCE" ]] || error_exit "Ce n'est pas un répertoire : $SOURCE"
[[ -r "$SOURCE" ]] || error_exit "Permission refusEe : répertoire non lisible : $SOURCE"

# --- Vérifier destination ---
[[ -d "$BACKUP_DIR" ]] || error_exit "Le dossier de destination n'existe pas : $BACKUP_DIR"
[[ -w "$BACKUP_DIR" ]] || error_exit "Permission refusée : impossible d'écrire dans : $BACKUP_DIR"

ARCHIVE_PATH="${BACKUP_DIR}/${ARCHIVE_NAME}"

# --- Nettoyage en cas d'échec (archive partielle) + log ---
cleanup() {
  if [[ -f "$ARCHIVE_PATH" ]]; then
    rm -f "$ARCHIVE_PATH" 2>/dev/null || true
  fi
}
trap cleanup ERR INT TERM

# --- Vérifier espace disque disponible (exigence 1.2) ---
# Taille source (Ko) et espace libre destination (Ko)
SRC_KB="$(du -sk "$SOURCE" | awk '{print $1}')"
FREE_KB="$(df -Pk "$BACKUP_DIR" | awk 'NR==2{print $4}')"

# marge 10% (compression pas garantie, + métadonnées)
NEEDED_KB=$(( SRC_KB + (SRC_KB / 10) + 1024 ))

if (( FREE_KB < NEEDED_KB )); then
  error_exit "Espace disque insuffisant sur la destination. Libre=${FREE_KB}KB, requis≈${NEEDED_KB}KB."
fi

# ---- Création de l’archive tar.gz ----
# On se place dans le parent pour éviter d’embarquer tout le chemin absolu dans l’archive
PARENT_DIR="$(cd "$(dirname "$SOURCE")" && pwd)"
[[ -x "$PARENT_DIR" ]] || echo "Accès refusé au dossier parent : $PARENT_DIR"
exit 1

tar -C "$PARENT_DIR" -czf "$ARCHIVE_PATH" "$FOLDER_NAME" \
  || error_exit "Échec lors de la création de l'archive."

# ---- Taille + message de confirmation ----
FOLDER_SIZE="$(du -h "$ARCHIVE_PATH" | awk '{print $1}')"

echo "All good! Sauvegarde terminEe"
echo "Source  : $SOURCE"
echo "Archive : $ARCHIVE_PATH"
echo "Taille  : $FOLDER_SIZE"

log_line "INFO" "Succès | archive=$ARCHIVE_PATH | taille=$SIZE_HUMAN"