#!/bin/bash

# appel a un script d'export samba : samba_export_users.sh
ssh root@SAMBASERVER './samba-export-users.sh'
sleep 2
scp root@SAMBASERVER:/root/users-export/valid_users_clean.csv .

# on grep les users de la base sam
ldbsearch -H /var/lib/samba/private/sam.ldb | grep "sAMAccountName" | cut -d ":" -f 2 | sed 's/ //g' >> users-from-ad.csv

sleep 2

# on save les lignes de A dans un array
lines_in_file_a=($(cat valid_users_clean.csv))

# boucle pour chaque ligne de a
for line in "${lines_in_file_a[@]}"; do
  # grep pour ligne dans b
  if grep -q "$line" users-from-ad.csv; then
  :
  else
    # si pas present dans b, echo
    echo "$line"
  fi

done > users-not-found.csv

sed -i '/@Domainadmins/d' users-not-found.csv

cat users-not-found.csv | mail -s "Samba users missing in AD" system@yourcompany.fr
