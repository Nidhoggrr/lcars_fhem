#!/bin/bash
for i in "17 C" "25 C" fnordlicht balcony boblight ceiling coffee "ikea lamp" lock unlock monitor "xmas star"
do
echo $i
file=$(echo ${i} | tr -d " ").svg
sed "s/MASTER/${i^^}/" master.svg > "${file}"
done

for i in save learn
do
echo $i
file=$(echo ${i} | tr -d " ").svg
sed "s/CONFIG/${i^^}/" config.svg > "${file}"
done


#heat_off.svg
#heat_on.svg
#home.svg
#media_off.svg
#media_on.svg
#switch_off.svg
#switch_on.svg
