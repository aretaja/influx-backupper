#! /bin/bash

# install files from repo to $destination
# and change permissions

destination='/usr/local/bin'
echo "Installing executables to $destination ..."

# make sure we are root
if [[ $EUID -ne 0 ]]
then
   echo 'This script must be run as root' 1>&2
   exit 1
fi

if [ ! -d $destination ]
then
    echo "Destination directory $destination not exists! Interrupting." 1>&2
    exit 1
fi

files=`find . ! -path "*/\.*" ! -name "install.sh" -type f -exec echo '{}' \; |sed 's%./%%'`
for f in $files
do
    cp --parents "$f" $destination
    chown root:root "${destination}/${f}"
    chmod 0755 "${destination}/${f}"
done

echo 'Done'
exit
