# pg_ldap_sync
A simple bash script to sync AD (LDAP) groups users with Postgresql.
This script adds users to Postgres server and adds them into the specified group.
Authentication auto set up is not implemented yet, so you have to edit the pg_hba.conf file manually, like that:
TYPE	DATABASE	USER	ADDRESS		METHOD
host	all			all		0.0.0.0/0	ldap	ldapserver=10.10.10.10.11 ldapprefix="" ldapsuffix="@example.local"
The script requires ldap-utils or openldap-clients packages to be installed
The script should run inside the directory accessible to the postgres user to let psql use it as a working directory. 
