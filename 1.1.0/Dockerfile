FROM tutum/curl:trusty
MAINTAINER Jan Antala <j.antala@pygmalios.com>

# Install InfluxDB
ENV INFLUXDB_VERSION 1.1.1

RUN curl -s -o /tmp/influxdb_latest_amd64.deb https://dl.influxdata.com/influxdb/releases/influxdb_${INFLUXDB_VERSION}_amd64.deb && \
  dpkg -i /tmp/influxdb_latest_amd64.deb && \
  rm /tmp/influxdb_latest_amd64.deb && \
  rm -rf /var/lib/apt/lists/*

# Include files
ADD config.toml /config/config.toml
ADD run.sh /run.sh
RUN chmod +x /*.sh

# Environment settings
ENV INFLUXD_OPTS -config=/config/config.toml

# Admin server WebUI
EXPOSE 8083

# HTTP API
EXPOSE 8086

# Mount point
VOLUME ["/var/lib/influxdb"]

# Default command
ENTRYPOINT ["/run.sh"]
