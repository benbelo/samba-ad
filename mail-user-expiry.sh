#!/bin/bash

## Script permettant d'envoyer un mail à un utilisateur lorsque la date d'expiration de son compte AD est dans moins de 30 jours

# Liste des utilisateurs, lister depuis une OU principale, ce n'est pas possible avec samba-tools
userlist=$(ldbsearch -H /var/lib/samba/private/sam.ldb -b 'OU=personnel,OU=utilisateurs,DC=lan,DC=entreprise,DC=fr' '(&(objectClass=user)(!(userAccountControl:1.2.840.113556.1.4.803:=2))(|(!(accountExpires=*))(accountExpires>=1)))' | grep sAMAccountName | awk '{print $2}')

rm /tmp/comptes-expires.txt

for login in $userlist; do

    # Recup de l'expiration du user avec le script ad-read-attr
    expiration=$(ad-read-attr.sh $login accountExpires | awk '{print $2}')
    mailaddress=$(ad-read-attr.sh $login mail | awk '{print $2}')
    actualdate=$(date +%s)

    win_epoch=$expiration
    # Nombre d'intervales entre le premier janvier 1601 et 1970 parce que le timestamp de microsoft c'est du caca
    accountExpiresOffset=$((11644473600 * 10000000))

    unix_time=$(( (win_epoch - accountExpiresOffset) / 10000000 ))
    expirationreelle=$(date -d @$unix_time)

    time_diff=$(($unix_time - $actualdate))

    # Diff 
    if [ "$time_diff" -le 2592000 ]; then
        # Corps du mail
        email_body="Bonjour, votre compte informatique expire dans moins de 30 jours, merci de vous rapprocher des ressources humaines pour actualisation de la date de votre fin de contrat."
        
	# Listing des comptes expirés pour envoi du mail récapitulatif
	echo $login,$mailaddress >> /tmp/comptes-expires.txt
        
	# Envoi du mail
        echo -e "$email_body" | mail -s "Compte informatique de $login expire dans moins de 30 jours" $mailaddress compte-info@entreprise.fr
    else
        echo "Le compte $login expire dans plus de 30 jours"
    fi

done

echo -e "$(cat /tmp/comptes-expires.txt)" | mail -s "Liste des comptes AD expirés" compte-info@entreprise.fr
