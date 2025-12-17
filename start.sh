#!/bin/bash

if [[ -v DB_USER && -v DB_PASSWORD && -v DB_HOST && -v KONG_PG_USER && -v KONG_PG_PASSWORD && -v KONG_PG_DATABASE && -v KONG_PG_SCHEMA ]]; then
  URI="postgres://$DB_USER:$DB_PASSWORD@$DB_HOST/postgres"
  psql "$URI" -c "CREATE USER $KONG_PG_USER CREATEDB PASSWORD '$KONG_PG_PASSWORD'" || true
  psql "$URI" -c "CREATE DATABASE $KONG_PG_DATABASE;" || true
  psql "$URI" -c "GRANT ALL PRIVILEGES ON DATABASE $KONG_PG_DATABASE TO $KONG_PG_USER;" || true

  URI="postgres://$DB_USER:$DB_PASSWORD@$DB_HOST/$KONG_PG_DATABASE"
  psql "$URI" -c "CREATE SCHEMA $KONG_PG_SCHEMA;" || true
  psql "$URI" -c "GRANT SELECT, INSERT, UPDATE, DELETE ON ALL TABLES IN SCHEMA $KONG_PG_SCHEMA TO $KONG_PG_USER;" || true
  psql "$URI" -c "GRANT EXECUTE ON ALL FUNCTIONS IN SCHEMA $KONG_PG_SCHEMA TO $KONG_PG_USER;" || true
  psql "$URI" -c "GRANT ALL ON SCHEMA $KONG_PG_SCHEMA TO $KONG_PG_USER;" || true
fi

kong migrations list
code=$?
[[ $code -eq 3 ]] && kong migrations bootstrap && kong migrations up && kong migrations finish
[[ $code -eq 4 ]] && kong migrations finish
[[ $code -eq 5 ]] && kong migrations up && kong migrations finish

kong start --nginx-conf custom-nginx.template
