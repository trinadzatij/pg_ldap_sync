#!/bin/bash

#This script adds users to Postgres server and adds them into the specified group.
#Authentication auto set up is not implemented yet, so you have to edit the pg_hba.conf file manually, like that:
#TYPE	DATABASE	USER	ADDRESS		METHOD
#host	all			all		0.0.0.0/0	ldap	ldapserver=10.10.10.10.11 ldapprefix="" ldapsuffix="@example.local"
#The script requires ldap-utils or openldap-clients packages to be installed
#The script should run inside the directory accessible to the postgres user to let psql use it as a working directory
#Just fill the settings below in the main section and run the script

main () {
#Active Directory Server and port in format IP:PORT
AD_DS_SERVER="10.10.10.11:389"

#Username, password, and OU of the user who is allowed to search in the domain (basically, every enabled domain user, so the precreated service account will do)
DOMAIN_USER="bind@example.local"
DOMAIN_USER_PASSWORD="PaS$Swo0rd"
DOMAIN_USER_LOCATION="OU=Users,DC=example,DC=local"

#The location of the AD group to sync in the domain
DOMAIN_GROUPS_LOCATION="OU=Groups,DC=example,DC=local"

#Run the sync function as many times as many groups you have to sync
#SYNC_LDAP "DOMAIN_GROUP_TO_SYNC" "PG_GROUP_TO_SYNC"
SYNC_LDAP "Postgres admins" "database_system_admin"
#SYNC_LDAP "Postgres users" "database_users"
#SYNC_LDAP "Postgres limited users" "database_limited_users"

}
SYNC_LDAP () {
#Parse AD Groups and get the lists of users
DATABASE_USERS_LIST=`ldapsearch -LLL -H "ldap://$AD_DS_SERVER" \
        -D $DOMAIN_USER \
        -w $DOMAIN_USER_PASSWORD \
        -b $DOMAIN_USER_LOCATION -s sub memberOf="CN=$1,$DOMAIN_GROUPS_LOCATION" sAMAccountName \
        | grep sAMA | cut -d" " -f2`

#Generate filenames for future use
NEW_LIST_FILE_NAME="new_"$2"_list"
OLD_LIST_FILE_NAME="old_"$2"_list"

#Create fresh existing users list file if there are none
if [[ ! -f $OLD_LIST_FILE_NAME ]];then
        FIRST_TIME="Yes"
        for NAME in $DATABASE_USERS_LIST
        do
                echo $NAME >> $OLD_LIST_FILE_NAME
        done
fi

#Create a list of current users
if [[ -f $NEW_LIST_FILE_NAME ]];then
        rm -f $NEW_LIST_FILE_NAME
fi
for NAME in $DATABASE_USERS_LIST
do
        echo $NAME >> $NEW_LIST_FILE_NAME
done

#Check if there is no difference between the old and the new lists and if it is not a first time run
if [[ -z `diff $NEW_LIST_FILE_NAME $OLD_LIST_FILE_NAME` ]] && [[ "$FIRST_TIME" -ne "Yes" ]]; then
        echo "Nothing to do"
        exit 0
fi

#Create lists of people to change inside Postgres
if [[ ! -z $FIRST_TIME ]]; then
        DATABASE_WINNERS=$DATABASE_USERS_LIST
else
        DATABASE_WINNERS=`diff $NEW_LIST_FILE_NAME $OLD_LIST_FILE_NAME | grep "<" | cut -d " " -f2`
fi
DATABASE_LOSERS=`diff $NEW_LIST_FILE_NAME $OLD_LIST_FILE_NAME | grep ">" | cut -d " " -f2`

#Create allowed users in Postgres
for ALLWD in $DATABASE_WINNERS
do
        echo "`date` created user $ALLWD in role $2" >> pg_ldap_sync.log
        sudo -u postgres psql -c "CREATE ROLE $ALLWD WITH LOGIN;"
        sudo -u postgres psql -c "GRANT $2 TO $ALLWD;"
done


#Drop disabled users in Postgres
for DSBLD in $DATABASE_LOSERS
do
        echo "`date` removed user $DSBLD from role $2" >> pg_ldap.cync.log
        sudo -u postgres psql -c "REVOKE $2 FROM $DSBLD;"
done


mv $NEW_LIST_FILE_NAME $OLD_LIST_FILE_NAME
}

main "$@"; exit


#Create list of people to change inside Postgres
DATABASE_WINNERS=`diff $NEW_LIST_FILE_NAME $OLD_LIST_FILE_NAME | grep "\<" | cut -d " " -f2`
DATABASE_LOSERS=`diff $NEW_LIST_FILE_NAME $OLD_LIST_FILE_NAME | grep "\>" | cut -d " " -f2`

#Create allowed users in Postgres
for ALLWD in $DATABASE_WINNERS
do
        sudo -u postgres psql -c "CREATE ROLE $ALLWD WITH LOGIN;"
        sudo -u postgres psql -c "GRANT $2 TO $ALLWD;"
done


#Drop disabled users in Postgres
for DSBLD in $DATABASE_LOSERS
do
        sudo -u postgres psql -c "ALTER ROLE $2 DROP ROLE $DSBLD;"
done


mv $NEW_LIST_FILE_NAME $OLD_LIST_FILE_NAME
}

main "$@"; exit
