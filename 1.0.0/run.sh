#!/bin/bash

set -e

# Daemon name, where is the actual executable
DAEMON=/usr/bin/influxd

# Configuration file
CONFIG=/etc/influxdb/influxdb.conf

# PID file for the daemon
PIDFILE=/var/run/influxdb/influxd.pid

# Log file for the daemon
LOGFILE=/var/log/influxdb/influxd.log

echo "=> Starting InfluxDB ..."

# Start Influxdb
exec $DAEMON -pidfile $PIDFILE -config $CONFIG $INFLUXD_OPTS
