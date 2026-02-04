#!/usr/bin/env bash
# backup.sh
# Objectif : créer une sauvegarde fiable (archive .tar.gz) d’un répertoire donné,
# en la nommant avec la date/heure, et en la stockant dans /backup (créer si besoin).

set -euo pipefail

# Dossier de destination demandé
BACKUP_DIR="/f/Atelier/Scripts"

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

# ---- Vérification du répertoire source + permissions ----
[[ -e "$SOURCE" ]] || error_exit "Le chemin n'existe pas : $SOURCE"
[[ -d "$SOURCE" ]] || error_exit "Ce n'est pas un répertoire : $SOURCE"
[[ -r "$SOURCE" ]] || error_exit "Permission refusEe : répertoire non lisible : $SOURCE"

# ---- Préparation de /backup ----
if [[ ! -d "$BACKUP_DIR" ]]; 
then
  mkdir -p "$BACKUP_DIR" 2>/dev/null || 
  echo "Impossible de créer $BACKUP_DIR (droits insuffisants ?)"
  exit 1
fi
[[ -w "$BACKUP_DIR" ]] || echo "Permission refusée : impossible d'écrire dans $BACKUP_DIR"
exit 1

# ---- Nouvelle variable ----
ARCHIVE_PATH="${BACKUP_DIR}/${ARCHIVE_NAME}"

# ---- Nettoyage en cas d'erreur (archive partielle) ----
cleanup() {
  [[ -f "$ARCHIVE_PATH" ]] && rm -f "$ARCHIVE_PATH" || true
}
trap cleanup ERR INT TERM

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
