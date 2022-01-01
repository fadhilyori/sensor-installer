#!/bin/bash

if [ "$EUID" -ne 0 ]
  then echo "Please run as root"
  exit
fi

command -v docker >/dev/null 2>&1 || { echo >&2 "This service requires Docker, but your computer doesn't have it. Install Docker then try again. Aborting."; exit 1; }

SCRIPTPATH="$( cd "$(dirname "$0")" >/dev/null 2>&1 ; pwd -P )"

read -p "Protected subnet : " PROTECTED_SUBNET
read -p "External subnet [default is any] : " EXTERNAL_SUBNET
EXTERNAL_SUBNET=${EXTERNAL_SUBNET:-any}
read -p "MQTT topic [default is snoqttv5] : " ALERT_MQTT_TOPIC
ALERT_MQTT_TOPIC=${ALERT_MQTT_TOPIC:-snoqttv5}
read -p "Mosquitto (MQTT Broker) IP : " ALERT_MQTT_SERVER
read -p "Mosquitto (MQTT Broker) Port [default is 1883] : " ALERT_MQTT_PORT
ALERT_MQTT_PORT=${ALERT_MQTT_PORT:-1883}
read -p "Device ID : " DEVICE_ID
echo "Available Network Interface : `ls -C /sys/class/net`"
read -p "Network Interface : " NETINT
read -p "Company : " COMPANY
echo -e "What kind rules do you want to use?\n\t1. Community\n\t2. Registered (required oinkcode)\n"
read -p "Your choice : " RULE_CHOICE

if [[ ! $RULE_CHOICE -eq 1 && ! $RULE_CHOICE -eq 2 ]]; then
  echo -e "Choose a valid choice.\nExited."
  exit 1
fi

echo "Preparing ..."
/usr/bin/docker pull mataelang/snorqttalpine-sensor:stable

echo "Configuring ..."
mkdir -p /etc/mataelang-sensor
cat > /etc/mataelang-sensor/sensor.env <<EOL
PROTECTED_SUBNET=${PROTECTED_SUBNET}
EXTERNAL_SUBNET=${EXTERNAL_SUBNET}
ALERT_MQTT_TOPIC=${ALERT_MQTT_TOPIC}
ALERT_MQTT_SERVER=${ALERT_MQTT_SERVER}
ALERT_MQTT_PORT=${ALERT_MQTT_PORT}
DEVICE_ID=${DEVICE_ID}
NETINT=${NETINT}
COMPANY=${COMPANY}
EOL
cp ${SCRIPTPATH}/service/mataelang-snort.service /etc/systemd/system/

if [[ $RULE_CHOICE -eq 1 ]]; then
  echo "Using Snort Community Rules.."
  docker tag mataelang/snorqttalpine-sensor:stable mataelang-snort
fi

if [[ $RULE_CHOICE -eq 2 ]]; then
  read -p "Input your oinkcode here : " OINKCODE
  /usr/bin/docker build --no-cache --build-arg OINKCODE=${OINKCODE} -f ${SCRIPTPATH}/dockerfiles/snort.dockerfile -t mataelang-snort ${SCRIPTPATH}/
fi

systemctl daemon-reload
echo "Registering Mata Elang sensor service..."
systemctl enable mataelang-snort.service
echo "Creating container..."
/usr/bin/docker create --name mataelang-sensor --network host -v /etc/localtime:/etc/localtime -v /etc/timezone:/etc/timezone --env-file /etc/mataelang-sensor/sensor.env mataelang-snort
echo "Starting sensor..."
systemctl start mataelang-snort.service

echo "Setup completed."
echo -e "You can start/stop/restart the service now with the following command : \n\tsudo systemctl start/stop/restart mataelang-snort"
