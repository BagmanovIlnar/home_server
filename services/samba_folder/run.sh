#!/usr/bin/env bash

#useradd -s /bin/true shareuser
echo "" >> /etc/samba/smb.conf
for fileName in $(ls /etc/samba/smb.conf.d); do
  cat "/etc/samba/smb.conf.d/$fileName" | while read y
  do
    echo $y >> /etc/samba/smb.conf
  done
done

/etc/init.d/smbd start
#service smbd start

echo "Press [CTRL+C] to exit this loop..."
while :
do
    sleep 2
done
