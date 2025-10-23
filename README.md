# influx-backupper
Script to make InfluxDB v2 backups of your data to local or remote target.
Requires bash, rsync on both ends and ssh key login without password to remote end.
Must be executed as root.

## Setup
* Prerequisites

Make sure you have **bash**, **rsync** installed on source and destination servers.

* Install
```
git clone https://github.com/aretaja/influx-backupper
cd influx-backupper
sudo ./install.sh
```

* Config

Config file location defaults to `/usr/local/etc/influx-backupper.conf`. Look at provided example config file.

## Usage
* Help
```
sudo influx-backupper.sh -h

Make daily, weekly, monthly InfluxDB backups.
Creates local or remeote backup:
  monthly on every 1 day of month in'influxdb_monthly' directory,
  weekly on every 1 day of week in 'influxdb_weekly' directory,
  every other day in 'influxdb_daily' directory.
Only latest backup will preserved in every directory.
Requires config file. Default: /usr/local/etc/influx-backupper.conf
Script must be executed by root.

Usage:
  influx-backupper.sh influx-backupper.conf
```

* Setup cron job for backup (Append to */etc/crontab*)
```
# InfluxDB backup
55 1    * * *   root    /usr/local/bin/influx-backupper.sh >>/var/log/influx-backupper.log 2>&1
```
