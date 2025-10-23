#!/bin/bash
set -euo pipefail
#
# influx-backupper.sh
# Copyright 2019-2025 by Marko Punnar <marko[AT]aretaja.org>
# Version: 4.0.0
#
# Script to make InfluxDB v2 backups of your data to remote
# target. Requires bash, rsync on both ends and ssh key login without
# password to remote end. Must be executed as root.
#
# This program is free software: you can redistribute it and/or modify
# it under the terms of the GNU General Public License as published by
# the Free Software Foundation, either version 3 of the License, or
# (at your option) any later version.
#
# This program is distributed in the hope that it will be useful,
# but WITHOUT ANY WARRANTY; without even the implied warranty of
# MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
# GNU General Public License for more details.
#
# You should have received a copy of the GNU General Public License
# along with this program.  If not, see <http://www.gnu.org/licenses/>
#
# Changelog:
# 1.0 Initial release
# 1.1 Use hardcoded config file
# 2.0.0 Change versioning. Minor non code changes
# 3.0.0 Make it work on InfluxDB v2. v1 is not supported anymore
# 4.0.0 Able to keep archives locally

# show help if requested
if [[ "$1" = '-h' ]] || [[ "$1" = '--help' ]]
then
    echo "Make daily, weekly, monthly InfluxDB backups."
    echo "Creates local or remeote backup:"
    echo "  monthly on every 1 day of month in'influxdb_monthly' directory,"
    echo "  weekly on every 1 day of week in 'influxdb_weekly' directory,"
    echo "  every other day in 'influxdb_daily' directory."
    echo "Only latest backup will preserved in every directory."
    echo "Requires config file. Default: /usr/local/etc/influx-backupper.conf"
    echo "Script must be executed by root."
    echo ""
    echo "Usage:"
    echo "       influx-backupper.sh influx-backupper.conf"
    exit 1
fi

### Functions ###############################################################
# Output formater. Takes severity (ERROR, WARNING, INEO) as first
# and output message as second arg.
write_log()
{
    tstamp=$(date -Is)
    if [[ "$1" = 'INFO'  ]]
    then
        echo "$tstamp [$1] $2"
    else
       echo "$tstamp [$1] $2" 1>&2
    fi
}
#############################################################################
# Make sure we are root
if [[ "$EUID" -ne 0 ]]
then
   write_log ERROR "$0 must be executed as root! Interrupting.."
   exit 1
fi

# Define default values
cfile="$1" || "/usr/local/etc/influx-backupper.conf"
lock_f="/var/run/influx-backupper.lock"
dest_local=1

# Check for running backup (lockfile)
if [[ -e "$lock_f" ]] && (( $(date +%s) - $(stat -c %Y $lock_f) < 86400 ))
then
    write_log ERROR "Previous backup is running (lockfile set in the last 24h). Interrupting.."
    exit 1
fi

# Load config
if [[ -r "$cfile" ]]
then
    # shellcheck source=./influx-backupper.conf_example
    . "$cfile"
else
     write_log ERROR "Config file missing! Interrupting.."
     exit 1
fi

# Check config
# shellcheck disable=SC1001
if [[ -z "$local_dest" ]] || [[ ! "$local_dest" =~ ^[[:alnum:]_\.\/-]+$ ]] || [[ ! -w "$local_dest" ]]
then
    write_log ERROR "Config - Local temp dir for backup missing or incorrect"
    exit 1
else
    # Change working dir
    cd "$local_dest"|| exit
    if [ "$PWD" != "$local_dest" ]
    then
        write_log ERROR "Wrong working dir - ${PWD}. Must be - ${local_dest}! Interrupting.."
        exit 1
    fi
fi

if [[ -z "${dbdir-}" ]] || [[ ! "$dbdir" =~ ^[[:alnum:]_\ \.\/-]+$ ]]
then
    write_log ERROR "Config - Backup destination basedir missing or incorrect"
    exit 1
fi

if [[ -n "${dhost-}" ]] && [[ -n "${dport-}" ]] && [[ -n "${duser-}" ]]
then
    dest_local=0
    if [[ ! "$dhost" =~ ^[[:alnum:]\.-]+$ ]]
    then
        write_log ERROR "Config - Backup destination host missing or incorrect"
        exit 1
    fi

    if [[ ! "$dport" =~ ^[[:digit:]]+$ ]]
    then
        write_log ERROR "Config - Backup destination ssh port missing or incorrect"
        exit 1
    fi

    if [[ ! "$duser" =~ ^[[:alnum:]_\.-]+$ ]]
    then
        write_log ERROR "Config - Backup destination ssh user missing or incorrect"
        exit 1
    fi
fi

# Set remote directory name
target="daily"
day_of_month=$(date +%-d)
day_of_week=$(date +%u)

if [[ "$day_of_month" -eq 1 ]]
then
    target="monthly"
elif [[ "$day_of_week" -eq 1 ]]
then
    target="weekly"
fi
ddir="influxdb_${target}"

# Set lockfile
touch "$lock_f";

if [[ "$dest_local" -eq 0 ]]
then
    # Connection check
    # shellcheck disable=SC2029
    if ! result=$(ssh -q -o BatchMode=yes -o ConnectTimeout=10 -l"$duser" -p"$dport" "$dhost" "cd \"$dbdir\"" 2>&1)
    then
        if [[ -z "$result" ]]
        then
            write_log ERROR "$dhost is not reachable! Interrupting.."
        else
            write_log ERROR "$dhost returned \"${result}\"! Interrupting.."
        fi
        rm "$lock_f"
        exit 1
    else
        write_log INFO "$dhost connection test OK"
    fi
fi

# Make InfluxDB backup to local temp directory
write_log INFO "InfluxDB - start backup to local temp directory: ${local_dest}. Influx log follows:"

# shellcheck disable=SC2012
if [[ $(ls -1 "${local_dest}" |wc -l) -gt 0 ]]
then
    write_log INFO "InfluxDB - local temp directory contains files. Deleting all old backup files from $local_dest"
    cmd="rm \"${local_dest}/\"[0-9]*T[0-9]*Z.*"
    eval "$cmd"
fi

cmd="influx backup \"${local_dest}\""
eval "$cmd" 2>&1
ret=$?
if [[ "$ret" -eq 0 ]]
then
    write_log INFO "InfluxDB - local backup success"
else
    write_log ERROR "InfluxDB - local backup failed. Interrupting!"
    rm "$lock_f"
    exit 1
fi

# Move backup files to the target
if [[ "$dest_local" -eq 0 ]]
then
    write_log INFO "rsync - move files to \"${duser}\"@${dhost}:\"${dbdir}/${ddir}\". Rsync log follows:"
    cmd="rsync -aHAXh --remove-source-files --delete --timeout=300 --stats --numeric-ids -M--fake-super -e 'ssh -o BatchMode=yes -p${dport}' \"${local_dest}/\" \"${duser}\"@${dhost}:\"${dbdir}/${ddir}\""
else
    write_log INFO "rsync - move files to \"${dbdir}/${ddir}\". Rsync log follows:"
    cmd="rsync -aHAXh --remove-source-files --delete --stats \"${local_dest}/\" \"${dbdir}/${ddir}\""
fi

for i in $(seq 1 10)
do
    eval "$cmd" 2>&1
    ret=$?
    if [[ "$ret" -eq 0 ]]; then break; fi
    write_log WARNING "rsync - got non zero exit code - $ret.! Retry $i from 10"
    sleep 60
done
if [[ "$ret" -ne 0 ]]
then
    write_log ERROR "rsync - got non zero exit code - $ret. Giving up"
    rm "$lock_f"
    exit 1
fi

write_log INFO "InfluxDB - all backup done"
rm "$lock_f"
exit 0
