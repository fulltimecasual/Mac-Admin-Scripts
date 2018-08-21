#!/bin/sh

# Version: v2.0
# Date: 2018-07-27

LOG=/var/log/enable_remote_setup.log

LOCAL_ADMIN_USER=depadmin

LOCAL_ADMIN_REALNAME='DEP Admin'

LOCAL_ADMIN_PASSWORD='Apple1234'

# Create local admin account
/usr/sbin/sysadminctl -addUser "${LOCAL_ADMIN_USER}" -fullName "${LOCAL_ADMIN_REALNAME}" -password "${LOCAL_ADMIN_PASSWORD}" -home "/Users/${LOCAL_ADMIN_USER}" -admin

sleep 10

# Create local admin user's home directory
/usr/sbin/createhomedir -c -u $LOCAL_ADMIN_USER

# Enable SSH
/usr/sbin/systemsetup -setremotelogin on

# Enable ARD for local admin
/System/Library/CoreServices/RemoteManagement/ARDAgent.app/Contents/Resources/kickstart -activate -configure -access -on -privs -all -users $LOCAL_ADMIN_USER 

# Get computer's serial number
serial_number=$(system_profiler SPHardwareDataType | awk '/Serial Number/ { print $4; }')

computer_model=$(/usr/sbin/system_profiler SPHardwareDataType | grep "Model Name" | awk '{ print $3, $4, $5 }')

# Remove trailing whitespace
computer_model=$(echo "${computer_model}" | sed -e 's/[[:space:]]*$//')

computer_name="Setup ${computer_model} ${serial_number}"

echo "$(date '+%Y-%m-%d %H:%M:%S') Setting computer name: ${computer_name}" >> $LOG

# Set computer name
/usr/sbin/scutil --set ComputerName "${computer_name}"

if [ $? -ne 0 ]
then
    echo "$(date '+%Y-%m-%d %H:%M:%S') Setting computer name failed" >> $LOG
fi 

exit 0