#!/usr/bin/env bash
# backup.sh
# Objectif : créer une sauvegarde fiable (archive .tar.gz) d’un répertoire donné,
# en la nommant avec la date/heure, et en la stockant dans /backup (créer si besoin).

# SOURCE="$1" # Argument du répertoire à sauvegarder
# echo "Répertoire à sauvegarder : $SOURCE"

FOLDER_NAME=$(basename $SOURCE) # Récupère le nom du dossier à sauvegarder (Source)
