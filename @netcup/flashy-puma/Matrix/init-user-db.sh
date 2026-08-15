#!/bin/bash
set -e

echo "Running init-user-db.sh as $POSTGRESQL_USERNAME on $POSTGRESQL_DATABASE"

export PGPASSWORD="$POSTGRESQL_PASSWORD"
psql -v ON_ERROR_STOP=1 --username "$POSTGRESQL_USERNAME" --dbname "$POSTGRESQL_DATABASE" <<-EOSQL

        CREATE USER synapse WITH PASSWORD '<synapse>';
        CREATE DATABASE synapse WITH OWNER synapse;

        CREATE USER matrixauthenticationservice WITH PASSWORD '<matrixauthenticationservice>';
        CREATE DATABASE matrixauthenticationservice WITH OWNER matrixauthenticationservice;

EOSQL

echo "Finished executing init-user-db.sh"