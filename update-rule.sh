#!/bin/bash

if [ "$EUID" -ne 0 ]
  then echo "Please run as root"
  exit
fi

command -v docker >/dev/null 2>&1 || { echo >&2 "This service requires Docker, but your computer doesn't have it. Install Docker then try again. Aborting."; exit 1; }

SCRIPTPATH="$( cd "$(dirname "$0")" >/dev/null 2>&1 ; pwd -P )"
IMAGE_TAG=dev
IMAGE_NAME=mataelang/snorqttsensor-stable

echo "Shutting down Mata Elang Snort Sensor"
systemctl stop mataelang-snort.service

echo -e "What kind rules do you want to use?\n\t1. Community\n\t2. Registered (required oinkcode)\n"
read -p "Your choice : " RULE_CHOICE

if [[ ! $RULE_CHOICE -eq 1 && ! $RULE_CHOICE -eq 2 ]]; then
  echo -e "Choose a valid choice.\nExited."
  exit 1
fi

echo "Removing the old container and image ..."
/usr/bin/docker container rm mataelang-sensor
/usr/bin/docker image rm mataelang-snort

echo "Preparing ..."
/usr/bin/docker pull ${IMAGE_NAME}:${IMAGE_TAG}

echo "Building the Docker Image..."
if [[ $RULE_CHOICE -eq 1 ]]; then
  echo "Using Snort Community Rules.."
  docker tag ${IMAGE_NAME}:${IMAGE_TAG} mataelang-snort
fi

if [[ $RULE_CHOICE -eq 2 ]]; then
  read -p "Input your oinkcode here : " OINKCODE
  /usr/bin/docker build --no-cache --build-arg IMAGE_TAG=${IMAGE_TAG} --build-arg OINKCODE=${OINKCODE} -f ${SCRIPTPATH}/dockerfiles/snort.dockerfile -t mataelang-snort ${SCRIPTPATH}/
fi

echo "Re-creating container..."
/usr/bin/docker create --name mataelang-sensor --network host -v /etc/localtime:/etc/localtime -v /etc/timezone:/etc/timezone -v /var/log/mataelang-sensor:/var/log/mataelang-sensor --env-file /etc/mataelang-sensor/sensor.env mataelang-snort
echo "Starting sensor..."
systemctl start mataelang-snort.service
