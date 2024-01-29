#!/bin/sh
while getopts u: flag
do
  case "$flag" in
    u) username=${OPTARG};;
  esac
done
docker exec -it service_samba_folder bash -c "smbpasswd -x $username";
docker exec -it service_samba_folder bash -c "deluser $username";
docker exec -it service_samba_folder bash -c "rmdir -R /var/home-service/users/$username";
#docker exec -t service_ftp1 bash -c "deluser $username";


