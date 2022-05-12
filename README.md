# influx-backupper
Script to make InfluxDB backups of your data to remote target. Requires bash, rsync on both ends and ssh key login without password to remote end. Must be executed as root.

## Setup
* Prerequisites
Make sure you have **bash**, **rsync** installed on source and destination servers.

* Install ibackupper
```
git clone https://github.com/aretaja/influx-backupper
cd influx-backupper
sudo ./install.sh
```

* Config
Config file must be located in `/usr/local/bin`. Look at provided example config file.

## Usage
* Help
```
sudo influx-backupper.sh -h

Make daily, weekly, monthly InfluxDB backups.
Creates monthly backup on every 1 day of month in remeote
'influxdb_monthly' directory, weekly on every 1 day of week in
'influxdb_weekly' directory and every other day in 'influxdb_daily'
directory. Only latest backup will preserved in every directory.
Requires config file: /usr/local/etc/<configfile>
Script must be executed by root.

Usage:
       influx-backupper.sh influx-backupper.conf
```

* Setup cron job for backup (Append to */etc/crontab*)
```
# InfluxDB backup
55 1    * * *   root    /usr/local/bin/influx-backupper.sh >>/var/log/ibackupper.log 2>&1
```
