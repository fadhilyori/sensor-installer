#!/bin/bash

function usage() {
  cat <<USAGE
    Mata Elang Sensor (Snort) | Update Snort Rules
    
    Usage: sudo ./update-rule.sh [OPTIONS]

    Options:
      -h | --help                 Print this message
      -k | --oinkcode             Oinkcode for downloading registered rules (required if using registered rules)
      -n | --no-ask               No asking (non-interactive)
      -t | --tag                  Define the image tag to use (default: 1.0)
      --community                 Use the community rules (already default)
      --registered                Use the registered rules (required oinkcode, use with -k or --oinkcode flag)


USAGE

  exit 1
}

SCRIPTPATH="$( cd "$(dirname "$0")" >/dev/null 2>&1 || exit ; pwd -P )"
IMAGE_TAG="1.0"
IMAGE_NAME=mataelang/snorqttsensor-stable
NO_ASK=false

while [ "$1" != "" ]
do
  case $1 in
    -t | --tag)
      shift
      IMAGE_TAG=${1:-1.0}
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
    if [ -z "$RULE_CHOICE" ]; then
      echo -e "What kind rules do you want to use?\n\t1. Community\n\t2. Registered (required oinkcode)\n"
      read -rp "Your choice : " RULE_CHOICE
    fi

    if [[ ! $RULE_CHOICE -eq 1 && ! $RULE_CHOICE -eq 2 ]]; then
      echo -e "Choose a valid choice.\nExited."
      exit 1
    fi

    if [[ $RULE_CHOICE -eq 2 ]] && [[ -z $OINKCODE ]]; then
      read -rp "Input your oinkcode here : " OINKCODE
    fi
  else
    printf "Your shell is not in interactive mode. Exiting"
    exit 1
  fi
else
  # non-interactive
  # check the value
  IMAGE_TAG=${IMAGE_TAG:-1.0}
  RULE_CHOICE=${RULE_CHOICE:-1}

  if [ -z "$OINKCODE" ] && [ "$RULE_CHOICE" == 2 ]; then
    printf "Oinkcode is required if using registered rules\n"
    exit 1
  fi
fi

printf "\nShutting down Mata Elang Snort Sensor..."
systemctl stop mataelang-snort.service

printf "[done]\nRemoving the old container and image: "
/usr/bin/docker container rm mataelang-sensor
/usr/bin/docker image rm mataelang-snort

printf "\nPreparing ...\n"
/usr/bin/docker pull ${IMAGE_NAME}:"${IMAGE_TAG}"

printf "\nBuilding the Docker Image: "
if [[ $RULE_CHOICE -eq 1 ]]; then
  printf "\nUsing Snort Community Rules.."
  docker tag ${IMAGE_NAME}:"${IMAGE_TAG}" mataelang-snort
elif [[ $RULE_CHOICE -eq 2 ]]; then
  /usr/bin/docker build --no-cache --build-arg IMAGE_TAG="${IMAGE_TAG}" --build-arg OINKCODE="${OINKCODE}" -f "${SCRIPTPATH}"/dockerfiles/snort.dockerfile -t mataelang-snort "${SCRIPTPATH}"/
fi

printf "\nRe-creating container: "
/usr/bin/docker create --name mataelang-sensor --network host -v /etc/localtime:/etc/localtime -v /etc/timezone:/etc/timezone -v /var/log/mataelang-sensor:/var/log/mataelang-sensor --env-file /etc/mataelang-sensor/sensor.env mataelang-snort
printf "\nStarting sensor..."
systemctl start mataelang-snort.service

printf "[done] \nDone.\n"
