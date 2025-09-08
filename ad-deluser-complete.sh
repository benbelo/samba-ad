. /usr/local/sbin/ad-conffiles
kinit script@LAN.ENTREPRISE.FR <<< $etpaf >/dev/null

[ $# -eq 0 ] && echo "Usage: `basename $0` user_1 user_2 user_n | file.csv" && exit 1

LIST=$@
[ $# -eq 1 ] && [ -f $1 ] && LIST=$(cat $1 | tr -d '\r' | grep -v 'login.Individu')

# Too late !

GLOBALERROR=0
for user in $LIST ; do

    samba-tool user show $user >/dev/null
    [ $? -ne 0 ] && exit 1

    # Creating gaccount variable for further use
    gaccount=$(search-ad.sh -l $user | awk '{print $3}')

    ERROR=0
    # Samba
    samba-tool user delete $user
    if [ $? -ne 0 ];then
        echo "$user not deleted in AD"
        ERROR+=1
    else
        echo "$user deleted on AD"
    fi

    # Homedir
    HOMEDIR=$(ssh files "readlink /user/$user")
#	HOMEDIR=${HOMEDIR%?}
    ssh files "mv $HOMEDIR ${HOMEDIR}.sup && rm /user/$user"
    if [ $? -ne 0 ];then
        echo "$user's home not moved ($HOMEDIR)"
        ERROR+=1
    else
        echo "$user's home moved ($HOMEDIR)"
    fi

    # LDAP
    ssh servitude@ldap "/home/servitude/bin/ldapdelete.sh $user"
    if [ $? -ne 0 ];then
        echo "$user not deleted in old LDAP"
        ERROR+=1
    else
        echo "$user deleted in old LDAP"
    fi

    ## Asking for deletion
    read -p "Are you sure you want to delete this Google account ? [yn]" answer
        if [[ $answer = y ]] ; then
               gmail-deluser-mailEntreprise.sh $gaccount;
        fi

    # Log and mail
    logs "Del user $user (AD+LDAP+Homedir) by $(get_ident)"
    echo "$(basename $0) --- $user" |mail -s "$(basename $0) --- $user" compte-info@entreprise.fr

    GLOBALERROR+=$ERROR
done

echo -e "Synchronizing Gmail with AD ..."
gmail-synchro-ad.sh 

exit $GLOBALERROR
