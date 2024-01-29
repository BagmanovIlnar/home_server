#!/bin/sh
while getopts u:p: flag
do
  case "$flag" in
    u) username=${OPTARG};;
    p) password=${OPTARG};;
  esac
done

#echo "username: $username"
#echo "password: $password"

docker exec -it service_samba_folder bash -c "useradd -s /bin/true $username | echo -e \"$password\\\n$password\" | smbpasswd -a $username"
docker exec -it service_samba_folder bash -c "mkdir /var/home-service/users/$username"
docker exec -it service_samba_folder bash -c "chown $username:$username /var/home-service/users/$username"
docker exec -it service_samba_folder bash -c "chmod 775 /var/home-service/users/$username"

#docker exec -t service_ftp1 bash -c "useradd -m -p $password $username"