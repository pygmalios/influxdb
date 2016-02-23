#!/bin/bash

set -m
CONFIG_FILE="/config/config.toml"
INFLUX_HOST="localhost"
INFLUX_API_PORT="8086"
API_URL="http://${INFLUX_HOST}:${INFLUX_API_PORT}"
ADMIN=${ADMIN_USER:-root}
PASS=${INFLUXDB_INIT_PWD:-root}

wait_for_start_of_influxdb(){
    #wait for the startup of influxdb
    RET=1
    while [[ RET -ne 0 ]]; do
        echo "=> Waiting for confirmation of InfluxDB service startup ..."
        sleep 3
        curl -k ${API_URL}/ping 2> /dev/null
        RET=$?
    done
}


# Dynamically change the value of 'max-open-shards' to what 'ulimit -n' returns
sed -i "s/^max-open-shards.*/max-open-shards = $(ulimit -n)/" ${CONFIG_FILE}

# Configure InfluxDB Cluster
if [ -n "${FORCE_HOSTNAME}" ]; then
    if [ "${FORCE_HOSTNAME}" == "auto" ]; then
        echo "INFLUX_HOST: ${HOSTNAME}"
        /usr/bin/perl -p -i -e "s/hostname = \"localhost\"/hostname = \"${HOSTNAME}\"/g" ${CONFIG_FILE}
        #[meta]
        /usr/bin/perl -p -i -e "s/bind-address = \":8088\"/bind-address = \"${HOSTNAME}:8088\"/g" ${CONFIG_FILE}
        /usr/bin/perl -p -i -e "s/http-bind-address = \":8091\"/http-bind-address = \"${HOSTNAME}:8091\"/g" ${CONFIG_FILE}
        #[http]
        /usr/bin/perl -p -i -e "s/bind-address = \":8086\"/bind-address = \"${HOSTNAME}:8086\"/g" ${CONFIG_FILE}
    else
        echo "INFLUX_HOST: ${FORCE_HOSTNAME}"
        /usr/bin/perl -p -i -e "s/hostname = \"localhost\"/hostname = \"${FORCE_HOSTNAME}\"/g" ${CONFIG_FILE}
        #[meta]
        /usr/bin/perl -p -i -e "s/bind-address = \":8088\"/bind-address = \"${FORCE_HOSTNAME}:8088\"/g" ${CONFIG_FILE}
        /usr/bin/perl -p -i -e "s/http-bind-address = \":8091\"/http-bind-address = \"${FORCE_HOSTNAME}:8091\"/g" ${CONFIG_FILE}
        #[http]
        /usr/bin/perl -p -i -e "s/bind-address = \":8086\"/bind-address = \"${FORCE_HOSTNAME}:8086\"/g" ${CONFIG_FILE}
    fi
fi

if [ "${PRE_CREATE_DB}" == "**None**" ]; then
    unset PRE_CREATE_DB
fi

echo "influxdb configuration: "
cat ${CONFIG_FILE}

echo "=> Starting InfluxDB ..."
if [ -n "${JOIN}" ]; then
  echo "in JOIN mode: ${JOIN}"
  echo "INFLUXD_OPTS=\"-config=${CONFIG_FILE} -join ${JOIN}\"" >> /etc/default/influxdb
  sudo service influxdb start
  sleep 10
  tail -F /var/log/influxdb/influxd.log
else
  echo "in MASTER mode"
  echo "INFLUXD_OPTS=\"-config=${CONFIG_FILE}\"" >> /etc/default/influxdb
  sudo service influxdb start
  sleep 10
  tail -F /var/log/influxdb/influxd.log
fi

if [ -f "/data/.init_script_executed" ]; then
  echo "=> The initialization script had been executed before, skipping ..."
else
  #Create the admin user
  if [ -n "${ADMIN_USER}" ] || [ -n "${INFLUXDB_INIT_PWD}" ]; then
    wait_for_start_of_influxdb
    echo "=> Creating admin user"
    influx -host=${INFLUX_HOST} -port=${INFLUX_API_PORT} -execute="CREATE USER ${ADMIN} WITH PASSWORD '${PASS}' WITH ALL PRIVILEGES"
  fi
  
  # Pre create database on the initiation of the container
  if [ -n "${PRE_CREATE_DB}" ]; then
    echo "=> About to create the following database: ${PRE_CREATE_DB}"
    arr=$(echo ${PRE_CREATE_DB} | tr ";" "\n")

    for x in $arr
    do
      echo "=> Creating database: ${x}"
      echo "CREATE DATABASE ${x}" >> /tmp/init_script.influxql
    done
  fi
  
  # Execute influxql queries contained inside /init_script.influxql
  if [ -f "/init_script.influxql" ] || [ -f "/tmp/init_script.influxql" ]; then
    echo "=> About to execute the initialization script"
  
    cat /init_script.influxql >> /tmp/init_script.influxql
  
    wait_for_start_of_influxdb
     
    echo "=> Executing the influxql script..." 
    influx -host=${INFLUX_HOST} -port=${INFLUX_API_PORT} -username=${ADMIN} -password="${PASS}" -import -path /tmp/init_script.influxql
  
    echo "=> Influxql script executed." 
    touch "/data/.init_script_executed"
  else
    echo "=> No initialization script need to be executed"
  fi
fi
