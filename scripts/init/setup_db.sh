#!/bin/bash
# setup_db.sh
# Purpose: Runs SQL init scripts in order inside the sqlserver-setup container.
# Called by docker-compose sqlserver-setup service.

set -e  # Exit immediately on error

SQLCMD="/opt/mssql-tools18/bin/sqlcmd"
CONN="-S sqlserver -U $SA_USERNAME -P $SA_PASSWORD -C"

echo ">>> [1/4] Creating database, schemas and UDFs..."
$SQLCMD $CONN -i /scripts/init/init_database.sql

echo ">>> [2/4] Creating bronze tables..."
$SQLCMD $CONN -d DataWarehouse -i /scripts/bronze/ddl_bronze.sql

echo ">>> [3/4] Creating bronze stored procedure..."
$SQLCMD $CONN -d DataWarehouse -i /scripts/bronze/proc_load_bronze.sql

echo ">>> [4/4] Loading CSV data into bronze layer..."
$SQLCMD $CONN -d DataWarehouse -Q "EXEC bronze.load_bronze"

echo ">>> Database setup complete."