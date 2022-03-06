#!/bin/bash

function usage() {
  cat <<USAGE
    Mata Elang Sensor (Snort) | Installer
    
    Usage: sudo ./setup.sh [OPTIONS]

    Options:
      -d | --device-id            Define the name or ID of the sensor
      -e | --external-subnet      Define external subnet for Snort (default: any)
      -h | --help                 Print this message
      -i | --interface            Define name of the interface to listen for Snort
      -k | --oinkcode             Oinkcode for downloading registered rules (required if using registered rules)
      -m | --company              Define the name of company or organization
      -n | --no-ask               No asking (non-interactive)
      -o | --topic                Define alert topic that used in MQTT Broker (default: snoqttv5)
      -p | --protected-subnet     Define protected subnet for Snort (default: any)
      -t | --tag                  Define the image tag to use (default: latest)
      --mqtt-broker-host          Define MQTT Broker Host
      --mqtt-broker-port          Define MQTT Broker Port (default: 1883)
      --community                 Use the community rules (already default)
      --registered                Use the registered rules (required oinkcode, use with -k or --oinkcode flag)


USAGE

  exit 1
}

SCRIPTPATH="$( cd "$(dirname "$0")" >/dev/null 2>&1 ; pwd -P )"
IMAGE_TAG=latest
IMAGE_NAME=mataelang/snorqttsensor-stable
NO_ASK=false

while [ "$1" != "" ]
do
  case $1 in
    -t | --tag)
      shift
      IMAGE_TAG=${1:-latest}
      ;;
    -p | --protected-subnet) 
      shift
      PROTECTED_SUBNET=${1:-any}
      ;;
    -e | --external-subnet)
      shift
      EXTERNAL_SUBNET=${1:-any}
      ;;
    -o | --topic)
      shift
      ALERT_MQTT_TOPIC=${1:-snoqttv5}
      ;;
    --mqtt-broker-host)
      shift
      ALERT_MQTT_SERVER=$1
      ;;
    --mqtt-broker-port)
      shift
      ALERT_MQTT_PORT=${1:-1883}
      ;;
    -d | --device-id)
      shift
      DEVICE_ID=$1
      ;;
    -i | --interface)
      shift
      NETINT=$1
      ;;
    -m | --company)
      shift
      COMPANY=$1
      ;;
    -k | --oinkcode)
      shift
      OINKCODE=$1
      ;;
    --community) 
      RULE_CHOICE=1
      ;;
    --registered)
      RULE_CHOICE=2
      ;;
    -h | --help) 
      usage
      exit 1
      ;;
    -n | --no-ask)
      NO_ASK=true
      ;;
  esac
  shift
done

if [ "$EUID" -ne 0 ]
  then echo "Please run as root"
  exit
fi

command -v docker >/dev/null 2>&1 || { echo >&2 "This service requires Docker, but your computer doesn't have it. Install Docker then try again. Aborting."; exit 1; }

if [ $NO_ASK != true ] ; then
  # Check if this Shell is interactive
  if [ -z "$PS1" ] ; then
    # interactive
    if [ -z "$PROTECTED_SUBNET" ]; then
      read -p "Protected subnet [default is any] : " PROTECTED_SUBNET
      PROTECTED_SUBNET=${PROTECTED_SUBNET:-any}
    fi

    if [ -z "$EXTERNAL_SUBNET" ]; then
      read -p "External subnet [default is any] : " EXTERNAL_SUBNET
      EXTERNAL_SUBNET=${EXTERNAL_SUBNET:-any}
    fi

    if [ -z "$ALERT_MQTT_TOPIC" ]; then
      read -p "MQTT topic [default is snoqttv5] : " ALERT_MQTT_TOPIC
      ALERT_MQTT_TOPIC=${ALERT_MQTT_TOPIC:-snoqttv5}
    fi
    
    if [ -z "$ALERT_MQTT_SERVER" ]; then
      read -p "Mosquitto (MQTT Broker) IP : " ALERT_MQTT_SERVER
    fi
    
    if [ -z "$ALERT_MQTT_PORT" ]; then
      read -p "Mosquitto (MQTT Broker) Port [default is 1883] : " ALERT_MQTT_PORT
      ALERT_MQTT_PORT=${ALERT_MQTT_PORT:-1883}
    fi
    
    if [ -z "$DEVICE_ID" ]; then
      read -p "Device ID : " DEVICE_ID
    fi
    
    if [ -z "$NETINT" ]; then
      echo "Available Network Interface : `ls -C /sys/class/net`"
      read -p "Network Interface : " NETINT
    fi
    
    if [ -z "$COMPANY" ]; then
      read -p "Company : " COMPANY
    fi
    
    if [ -z "$RULE_CHOICE" ]; then
      echo -e "What kind rules do you want to use?\n\t1. Community\n\t2. Registered (required oinkcode)\n"
      read -p "Your choice : " RULE_CHOICE
    fi

    if [[ ! $RULE_CHOICE -eq 1 && ! $RULE_CHOICE -eq 2 ]]; then
      echo -e "Choose a valid choice.\nExited."
      exit 1
    fi

    if [[ $RULE_CHOICE -eq 2 ]] && [[ -z $OINKCODE ]]; then
      read -p "Input your oinkcode here : " OINKCODE
    fi
  else
    printf "Your shell is not in interactive mode. Exiting"
    exit 1
  fi
else
  # non-interactive
  # check the value
  IMAGE_TAG=${IMAGE_TAG:-latest}
  PROTECTED_SUBNET=${PROTECTED_SUBNET:-any}
  EXTERNAL_SUBNET=${EXTERNAL_SUBNET:-any}
  ALERT_MQTT_TOPIC=${ALERT_MQTT_TOPIC:-snoqttv5}
  ALERT_MQTT_PORT=${ALERT_MQTT_PORT:-1883}
  RULE_CHOICE=${RULE_CHOICE:-1}

  if [ -z $ALERT_MQTT_SERVER ]; then
    printf "MQTT Broker host is required\n"
    exit 1
  fi

  if [ -z $DEVICE_ID ]; then
    printf "Device ID is required\n"
    exit 1
  fi

  if [ -z $NETINT ]; then
    printf "Network Interface is required\n"
    exit 1
  fi

  if [ -z $COMPANY ]; then
    printf "Company is required\n"
    exit 1
  fi

  if [ -z $OINKCODE ] && [ $RULE_CHOICE == 2 ]; then
    printf "Oinkcode is required if using registered rules\n"
    exit 1
  fi
fi

printf "\nPreparing ..."
/usr/bin/docker pull ${IMAGE_NAME}:${IMAGE_TAG}

printf "[done] \nConfiguring ..."
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
  printf "[done] \nUsing Snort Community Rules."
  docker tag ${IMAGE_NAME}:${IMAGE_TAG} mataelang-snort
elif [[ $RULE_CHOICE -eq 2 ]]; then
  /usr/bin/docker build --no-cache --build-arg IMAGE_TAG=${IMAGE_TAG} --build-arg OINKCODE=${OINKCODE} -f ${SCRIPTPATH}/dockerfiles/snort.dockerfile -t mataelang-snort ${SCRIPTPATH}/
fi

systemctl daemon-reload
printf "\nRegistering Mata Elang sensor service..."
systemctl enable mataelang-snort.service
printf "[done] \nRemoving old container: "
systemctl stop mataelang-snort.service
/usr/bin/docker container rm mataelang-sensor
printf "\nCreating container: "
/usr/bin/docker create --name mataelang-sensor --network host -v /etc/localtime:/etc/localtime -v /etc/timezone:/etc/timezone -v /var/log/mataelang-sensor:/var/log/mataelang-sensor --env-file /etc/mataelang-sensor/sensor.env mataelang-snort
printf "\nStarting sensor..."
systemctl start mataelang-snort.service

printf "[done] \n\nSetup completed."
printf "You can start/stop/restart the service now with the following command : \n\tsudo systemctl start/stop/restart mataelang-snort\n\n"
