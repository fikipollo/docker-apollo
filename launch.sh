#!/bin/bash

if [[ "${WEBAPOLLO_DB_HOST}" == "" ]]; then
	echo "Using internal postgresql service..."
	service postgresql start
	WEBAPOLLO_DB_HOST=127.0.0.1
else
	echo "Using external postgresql service (${WEBAPOLLO_DB_HOST})..."
	HOST_FLAG="-h ${WEBAPOLLO_DB_HOST}"
fi

until pg_isready $HOST_FLAG; do
	echo -n "."
	sleep 1;
done

echo "Postgres is up..."
su postgres -c "psql -lqt | cut -d \| -f 1 | grep -qw apollo"
if [[ "$?" == "1" ]]; then
	echo "Apollo database not found, creating..."
	su postgres -c "createdb $HOST_FLAG apollo"
	su postgres -c "psql $HOST_FLAG -c \"CREATE USER apollo WITH PASSWORD 'apollo';\""
	su postgres -c "psql $HOST_FLAG -c 'GRANT ALL PRIVILEGES ON DATABASE \"apollo\" to apollo;'"
fi

su postgres -c "psql -lqt | cut -d \| -f 1 | grep -qw chado"
if [[ "$?" == "1" ]]; then
	echo "Chado database not found, creating..."
	su postgres -c "createdb $HOST_FLAG chado"
	su postgres -c "psql $HOST_FLAG -c 'GRANT ALL PRIVILEGES ON DATABASE \"chado\" to apollo;'"
	su postgres -c "PGPASSWORD=apollo psql -U apollo -h ${WEBAPOLLO_DB_HOST} chado -f /chado.sql"
fi

# https://tomcat.apache.org/tomcat-8.0-doc/config/context.html#Naming
FIXED_CTX=$(echo "${CONTEXT_PATH}" | sed 's|/|#|g')
WAR_FILE=${CATALINA_HOME}/webapps/${FIXED_CTX}.war

cp ${CATALINA_HOME}/apollo.war ${WAR_FILE}

${CATALINA_HOME}/bin/shutdown.sh
${CATALINA_HOME}/bin/startup.sh

if [[ ! -f "${CATALINA_HOME}/logs/catalina.out" ]]; then
	touch ${CATALINA_HOME}/logs/catalina.out
fi

tail -f ${CATALINA_HOME}/logs/catalina.out
