# PostgreSQL

### Upgrading PostgreSQL
The easiest way to upgrade PostgreSQL to a new major version is to first export the database and then import it again after recreating the container with the new version.

**Export database:**
```bash
# all databases
pg_dumpall -c -U <db_user> -f <filename>.sql
# single database
pg_dump -c -U <db_user> (-d <db_name>) -f <filename>.sql
```

**Restore database:**
```bash
# using pg restore
pg_restore -U <db_user> (-d <db_name>) -f <filename>.dump
# using psql
psql -U <db_user> -d <db_name> < <filename>.sql
```
