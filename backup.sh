#!/usr/bin/env bash
# backup.sh
# Objectif : créer une sauvegarde fiable (archive .tar.gz) d’un répertoire donné,
# en la nommant avec la date/heure, et en la stockant dans /backup (créer si besoin).

if (( $# != 1 )) # on établit le nombre d'arguments, (dans ce cas ce n'est qu'un seul).
then
    echo "1 argument requis : $0 <repertoire_a_sauvegarder>"
    exit 1
fi
SOURCE="$1" # Argument du répertoire à sauvegarder

if [ ! -d $SOURCE ] #Vérification de l'existance du dossier
then
    echo "Le répertoire n'existe pas"
    exit 1
fi

DATE=$(date +"%Y-%m-%d_%H-%M-%S") # String pour la date actuelle, selon format décidé par nous
echo $DATE

FOLDER_NAME=$(basename $SOURCE) # Récupère le nom du dossier à sauvegarder (Source)

ARCHIVE_NAME="${FOLDER_NAME}_backup_${DATE}.tar.gz"

tar -czf $ARCHIVE_NAME $SOURCE # Création de l'archive en format .tar.gz

