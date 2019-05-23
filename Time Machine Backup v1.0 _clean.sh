#!/bin/sh

# TODO: Save existing Time Machine settings and restore after backup (SkipPaths, SkipSystemFiles)

# Version: 1.0
# Date: 2019-05-17

errno='0'

SERVER_DOMAIN='backups'

SERVER_HOST='backups.companyname.com'

SERVER_SHARE='MacClientBackups'

SERVER_USER='macclientbackups'

SERVER_PASSWORD='...'

SERVER_SHARE_MOUNT='/tmp/com.companyname.timemachine'

TIME_MACHINE_VOLUME='UNSW IT Time Machine Backups'

TIME_MACHINE_VOLUME_PATH="/Volumes/${TIME_MACHINE_VOLUME}"

#DISK_IMAGE_SIZE='500g'
DISK_IMAGE_SIZE='1000g'

SERIAL_NUMBER=$(system_profiler SPHardwareDataType | awk '/Serial Number/ { print $4; }')

user=$(ls -l /dev/console | awk '{ print $3 }')

#echo "user = $user"

# Is Time Machine already configured
TIME_DESTINATIONS=$(tmutil destinationinfo)

if [ "${TIME_DESTINATIONS}" !=  "tmutil: No destinations configured." ]
then
    echo "Error Time Machine already configured, please delete existing destinations and excluded items"
    exit 1
fi

# Remove server mount point if it already exists
if [ -e "${SERVER_SHARE_MOUNT}" ]
then
    rmdir ${SERVER_SHARE_MOUNT}

    if [ $? -ne 0 ]
    then
        echo "Error can't remove server mount point"
        exit 2
    fi
fi

# Create mount point
sudo -u $user mkdir ${SERVER_SHARE_MOUNT}

if [ $? -ne 0 ]
then
    echo "Error can't create mount point"
    exit 3
fi

echo "Mounting share"

# Mount share hidden
sudo -u $user mount -o nobrowse -t smbfs "//${SERVER_DOMAIN};${SERVER_USER}:${SERVER_PASSWORD}@${SERVER_HOST}/${SERVER_SHARE}" ${SERVER_SHARE_MOUNT}

if [ $? -ne 0 ]
then
    echo "Error can't mount share"
    exit 4
fi

# Does disk image doesn't already exist
if [ ! -e "${SERVER_SHARE_MOUNT}/${SERIAL_NUMBER}.sparsebundle" ]
then
    echo "Creating sparse bundle disk image, size ${DISK_IMAGE_SIZE}"

    # Create sparse bundle disk image with band size 128 MB
hdiutil create -size ${DISK_IMAGE_SIZE} -type SPARSEBUNDLE -nospotlight -volname "${TIME_MACHINE_VOLUME}" -fs "HFS+J" -imagekey sparse-band-size=262144 "${SERVER_SHARE_MOUNT}/${SERIAL_NUMBER}.sparsebundle"

    if [ $? -ne 0 ]
    then
        echo "Error can't create disk image"
        exit 5
    fi
fi

echo "Mounting disk image"

# Mount disk image hidden
sudo -u $user hdiutil attach "${SERVER_SHARE_MOUNT}/${SERIAL_NUMBER}.sparsebundle" -nobrowse -owners on

if [ $? -ne 0 ]
then
    echo "Error mounting disk image"
    exit 6
fi

echo "Stop Spotlight from indexing backups"

# Stop Spotlight from indexing backups
mdutil -E -i off "${TIME_MACHINE_VOLUME_PATH}"

echo "Setting Time Machine destination"

# Set Time Machine destination
tmutil setdestination "${TIME_MACHINE_VOLUME_PATH}"

if [ $? -ne 0 ]
then
    echo "Error setting Time Machine destination"
    exit 7
fi

# Get Time Machine destination ID
TIME_MACHINE_ID=$(tmutil destinationinfo | sed "1,/${TIME_MACHINE_VOLUME}/d" | grep -m 1 "ID" | cut -d ":" -f 2 | sed -e 's/^[ \t]*//')

# Add exclusions
tmutil addexclusion -p /Applications

tmutil addexclusion -p /Library

tmutil addexclusion -p /System

echo "Starting backup"

# Start backup and wait until the backup is finished
tmutil startbackup --block --destination ${TIME_MACHINE_ID}

if [ $? -ne 0 ]
then
    echo "Error during backup"

    errno='8'
#else
#    echo "Verifying backup"
#
#    tmutil verifychecksums "${TIME_MACHINE_VOLUME_PATH}"
#
#    if [ $? -ne 0 ]
#    then
#        echo "Error verifying backup"
#
#        errno='9'
#    fi
fi

echo "Removing Time Machine destination"

# Remove Time Machine destination
tmutil removedestination ${TIME_MACHINE_ID}

# Remove exclusions
tmutil removeexclusion -p /Applications

tmutil removeexclusion -p /Library

tmutil removeexclusion -p /System

sleep 60

echo "Unmounting disk image"

# Unmount disk image
hdiutil detach "${TIME_MACHINE_VOLUME_PATH}"

sleep 60

echo "Unmounting server share"

# Unmount server share
diskutil unmount "${SERVER_SHARE_MOUNT}"

exit $errno
