# Gestion d'utilisateurs
#!/bin/bash

#!/bin/bash
#!/bin/bash

CSV="$1"

if [ -z "$CSV" ] || [ ! -f "$CSV" ]; then
  echo "Usage: $0 users.csv"
  exit 1
fi

group_for_dept() {
  case "$1" in
    IT) echo "grp_it" ;;
    DEV) echo "grp_dev" ;;
    RH) echo "grp_rh" ;;
    *) echo "grp_users" ;;
  esac
}

gen_password() {
  openssl rand -base64 16
}

while IFS=',' read -r prenom nom dept; do
  [ "$prenom" = "Prenom" ] && continue

  login="$(echo "${prenom:0:1}${nom}" | tr 'A-Z' 'a-z')"
  fullname="$prenom $nom"
  group="$(group_for_dept "$dept")"

  getent group "$group" >/dev/null || groupadd "$group"

  password="$(gen_password)"

  useradd -m -g "$group" -c "$fullname" "$login"
  echo "$login:$password" | chpasswd

  echo "$login : $password"
done < "$CSV"
