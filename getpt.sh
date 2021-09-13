#!/usr/bin/env sh

# This script builds PeerTube official docker stack in /var/peertube
#
# SHELL command: `curl https://getpeer.tube | sh`
#
# Source: https://github.com/kimsible/getpeer.tube

{
#################
### CONSTANTS ###
#################

# Default branch
if [ ! "$GIT_BRANCH" ]; then
  GIT_BRANCH="master"
fi

# Peertube: https raw url of docker production PeerTube setup
PEERTUBE_DOCKER_RAW_URL=https://raw.githubusercontent.com/kimsible/getpeer.tube/$GIT_BRANCH

# Docker: needs version matching with v3.3 Compose file format
# https://docs.docker.com/compose/compose-file/compose-versioning/
DOCKER_PREREQUISITE_RELEASE=17.06.01

# Docker Compose binary path
COMPOSE=/usr/local/bin/docker-compose

# PeerTube Working directory
WORKDIR=/var/peertube

# PeerTube CLI binary path
CLI=/usr/sbin/peertube

# PeerTube Service Path
SERVICE_PATH=/etc/systemd/system/peertube.service

# Colors
ORANGE='\033[0;33m'
GREEN='\033[0;32m'
RED='\033[0;31m'
NC='\033[0m' # No Color

# Response Type
WARNING=${ORANGE}WARNING${NC}
ERROR=${RED}ERROR${NC}
OK=${GREEN}OK${NC}
DONE=${GREEN}done${NC}

#################
### FUNCTIONS ###
#################

# Test if a program is installed
has() {
  type "$1" > /dev/null 2>&1
}

curlf() {
  STATUSCODE=`curl -sSL --write-out "%{http_code}" $1 -o $2`
  [ "$STATUSCODE" -ne 200 ] && printf "%b" "$ERROR\n" && printf "%b" "${ORANGE}HTTP $STATUSCODE${NC} ${RED}$1${NC}\n" && exit 1
}

# Get latest file from GitHub raw
get_latest_file() {
  remote_path=$1
  local_path=$2
  curlf "$PEERTUBE_DOCKER_RAW_URL$remote_path" "$local_path"
}

# Get docker-compose release from GitHub
get_docker_compose() {
  release=$1
  download_url="https://github.com/docker/compose/releases/download/$release/docker-compose-`uname -s`-`uname -m`"
  curlf "$download_url" "$COMPOSE"
  chmod +x "$COMPOSE" # asign execution right
}

# Get latest release name from GitHub api
get_latest_release_name() {
  repo=$1
  api_url="https://api.github.com/repos/$repo/releases/latest"
  curl -sfL $api_url |
    grep '"tag_name":' |         # Get tag line
    sed -E 's/.*"([^"]+)".*/\1/' # Pluck JSON value
}

get_release_short() {
  release=$1
  release_short=`echo "${release%.*}"`
  echo "$release_short" | sed 's/v//g' # Remove prefix "v"
}

get_release_patch() {
  release=$1
  echo "${release##*.}"
}

get_release_major() {
  release=$1
  release_short=`get_release_short $release`
  echo "${release_short%.*}"
}

get_release_minor() {
  release=$1
  release_short=`get_release_short $release`
  echo "${release_short##*.}"
}

is_update() {
  current_release=$1
  latest_release=$2
  current_short=`get_release_short "$current_release"`
  latest_short=`get_release_short "$latest_release"`
  if [ "$current_short" = "$latest_short" ]; then
    current_patch=`get_release_patch "$current_release"`
    latest_patch=`get_release_patch "$latest_release"`
    [ "$latest_patch" -le "$current_patch" ] && true
  else
    latest_major=`get_release_major $latest_release`
    latest_minor=`get_release_minor $latest_release`
    current_major=`get_release_major $current_release`
    current_minor=`get_release_minor $current_release`
    [ "$latest_major" = "$current_major" ] && [ "$latest_minor" -le "$current_minor" ] && true || [ "$latest_major" -lt "$current_major" ] && true
  fi
}

get_current_release() {
  command=$1
  echo `$command` |grep -o -E "[0-9]{1,3}\.[0-9]{1,3}\.[0-9]{1,3}"
}

validate_domain() {
  echo "$1" |grep -P -i '^[a-z0-9]{1}[a-z0-9.-]*[a-z0-9]{1}\.[a-z]{2}'
}

validate_email() {
  echo "$1" |grep -P -i '^[a-z0-9]+@[a-z0-9]+\.[a-z]{2}'
}

prompt() {
  read -p "What is your $1? " INPUT

  while [ -z "`validate_$1 $INPUT`" ]; do
    printf "%b" "${ERROR}: ${ORANGE}$INPUT${NC} is not a valid $1, please enter a valid one\n" >&2 # prompt error after failed
    read -p "What is your $1? " INPUT
  done

  echo $INPUT
}

#################
##### MAIN ######
#################

# Step 1
printf "%b" "Prerequisites\n"
missing_prerequisites=0

# root
uid=`id -u`
if [ "$uid" -ne 0 ]; then
  missing_prerequisites=1
  sudo_command="curl https://getpeer.tube -o getpt.sh && sudo -E sh getpt.sh"
  printf "%b" " $ERROR: must be run as root or sudoer user with ${ORANGE}$sudo_command${NC}\n"
else
  printf "%b" " root $OK\n"
fi

# systemd
if ! has "systemctl"; then
  missing_prerequisites=1
  printf "%b" " $ERROR:systemd is missing\n"
else
  printf "%b" " systemd $OK\n"
fi

# curl
if ! has "curl"; then
  missing_prerequisites=1
  printf "%b" " $ERROR: curl is missing\n"
else
  printf "%b" " curl $OK\n"
fi

# docker
if ! has "docker"; then
  missing_prerequisites=1
  printf "%b" " $ERROR: docker >= $DOCKER_PREREQUISITE_RELEASE is missing\n"
else
  docker_current_release=`get_current_release "docker -v"`
  if ! is_update "$docker_current_release" "$DOCKER_PREREQUISITE_RELEASE"; then
    missing_prerequisites=1
    printf "%b" " $ERROR: docker >= $DOCKER_PREREQUISITE_RELEASE is required, found $docker_current_release\n"
  else
    printf "%b" " docker $OK\n"
  fi
fi

# domain
if [ ! -z "$MY_DOMAIN" ]; then
  if [ -z "`validate_domain $MY_DOMAIN`" ]; then
    missing_prerequisites=1
    printf "%b" " $ERROR: ${ORANGE}$MY_DOMAIN${NC} is not a valid domain\n"
  fi
fi

# email
if [ ! -z "$MY_EMAIL_ADDRESS" ]; then
  if [ -z "`validate_email $MY_EMAIL_ADDRESS`" ]; then
    missing_prerequisites=1
    printf "%b" " $ERROR: ${ORANGE}$MY_EMAIL_ADDRESS${NC} is not a valid email\n"
  fi
fi

# Exit if not all prerequisites
if [ "$missing_prerequisites" -ne 0 ]; then exit 1; fi

# Check if a stack is alreay installed
if [ -f $WORKDIR/.env ] || [ -f $WORKDIR/docker-compose.yml ] || [ -f $WORKDIR/docker-volume ]; then
  # Step 2
  printf "%b" "\n${ORANGE}Docker stack already exists in $WORKDIR${NC}\n"
  printf "%b" "\nUpgrading ${GREEN}Compose${NC} and ${GREEN}CLI${NC} only\ \n"
  UPGRADE=1
fi

# No need to prompt domain/email and create docker user when upgrading
if [ -z "$UPGRADE" ]; then
  # Prompt $MY_DOMAIN if not defined
  if [ -z $MY_DOMAIN ]; then
    MY_DOMAIN=`prompt "domain"`
  fi

  # Prompt $MY_EMAIL_ADDRESS if not defined
  if [ -z $MY_EMAIL_ADDRESS ]; then
    MY_EMAIL_ADDRESS=`prompt "email"`
  fi

  # Display used environment variables
  printf "%b" " ${ORANGE}admin email${NC} → using ${GREEN}$MY_EMAIL_ADDRESS${NC}\n"
  printf "%b" " ${ORANGE}domain name${NC} → using ${GREEN}$MY_DOMAIN${NC}\n"

  # Step 2
  printf "%b" "\nPreparing environment\ \n"

  # Docker: make sure a non-root docker user system exists
  printf "%b" "Creating a non-root docker user system ... "
  useradd >/dev/null 2>&1 -r -M -g docker docker # redirect out message if user already exists
  printf "%b" "$DONE\n"
fi

# Other architectures than x86_64
if [ -z "`uname -a | grep -o "x86_64"`" ]; then
  printf "%b" "$WARNING: Compose Binary can't be installed on your architecture\n"
  COMPOSE="docker-compose"
  if ! has "$COMPOSE"; then
    printf "%b" "$ERROR: Unfortunately docker-compose is not installed on your system\n"
    exit 1
  else
    compose_current_release=`get_current_release "$COMPOSE -v"`
    printf "%b" " → using system version ${GREEN}$compose_current_release${NC}\n"
  fi
else
  # Install or upgrade docker-compose
  printf "%b" "Checking latest release of Compose     ... "
  compose_latest_release=`get_latest_release_name "docker/compose"`
  [ -z "$compose_latest_release" ] && printf "%b" "${RED}Cannot resolve GitHub releases URL${NC}" && exit 1
  printf "%b" "$DONE\n"

  if ! has "$COMPOSE"; then
    printf "%b" "Installing Docker Compose $compose_latest_release       ... "
    get_docker_compose "$compose_latest_release"
    printf "%b" "$DONE\n"
    printf "%b" " → into ${ORANGE}$COMPOSE${NC}\n"
  else
    compose_current_release=`get_current_release "$COMPOSE -v"`

    if ! is_update "$compose_current_release" "$compose_latest_release"; then
      printf "%b" "Upgrading Docker Compose               ... "
      get_docker_compose "$compose_latest_release"
      printf "%b" "$DONE\n"
      printf "%b" " → from $compose_current_release to ${GREEN}$compose_latest_release${NC}\n"
    else
      printf "%b" " → using current version ${GREEN}$compose_current_release${NC}\n"
    fi
  fi
fi

# Get latest peertube cli
printf "%b" "Installing CLI into ${ORANGE}$CLI${NC} ... "
rm -f $CLI
get_latest_file "/cli/peertube" "$CLI"
chmod +x $CLI
printf "%b" "$DONE\n"

# Stop here if upgrading docker-compose / CLI
if [ ! -z "$UPGRADE" ]; then
  printf "%b" "\n${GREEN}Docker Compose and the CLI are now successfully upgraded!${NC}\n"
  exit 1
fi

# Init workdir
printf "%b" "Creating ${ORANGE}$WORKDIR${NC}                 ... "
mkdir -p "$WORKDIR/docker-volume"
cd "$WORKDIR"
mkdir -p docker-volume/certbot # Init docker-volume and certbot directory
mkdir -p docker-volume/nginx # Init nginx directory
printf "%b" "$DONE\n"

# Randomize PostgreSQL username and password
printf "%b" "Generating PostgreSQL credentials      ... "

MY_POSTGRES_USERNAME="`head /dev/urandom | tr -dc A-Za-z0-9 | head -c 10`"
MY_POSTGRES_PASSWORD=`date +%s | sha256sum | base64 | head -c 32`

printf "%b" "$DONE\n"

# Create / override .env
printf "%b" "Generating ${ORANGE}$WORKDIR/.env${NC}          ... "

cat <<EOT > .env
POSTGRES_USER=<MY POSTGRES USERNAME>
POSTGRES_PASSWORD=<MY POSTGRES PASSWORD>
POSTGRES_DB=peertube
PEERTUBE_DB_USERNAME=<MY POSTGRES USERNAME>
PEERTUBE_DB_PASSWORD=<MY POSTGRES PASSWORD>
PEERTUBE_DB_HOSTNAME=postgres
PEERTUBE_WEBSERVER_HOSTNAME=<MY DOMAIN>
PEERTUBE_TRUST_PROXY=["127.0.0.1", "loopback", "172.18.0.0/16"]
PEERTUBE_SMTP_HOSTNAME=postfix
PEERTUBE_SMTP_PORT=25
PEERTUBE_SMTP_FROM=noreply@<MY DOMAIN>
PEERTUBE_SMTP_TLS=false
PEERTUBE_SMTP_DISABLE_STARTTLS=false
PEERTUBE_ADMIN_EMAIL=<MY EMAIL ADDRESS>
POSTFIX_myhostname=<MY DOMAIN>
OPENDKIM_DOMAINS=<MY DOMAIN>=peertube
OPENDKIM_RequireSafeKeys=no
EOT

# Auto-fill .env file
sed -i -e "s/<MY EMAIL ADDRESS>/$MY_EMAIL_ADDRESS/g" .env
sed -i -e "s/<MY DOMAIN>/$MY_DOMAIN/g" .env
sed -i -e "s/<MY POSTGRES USERNAME>/$MY_POSTGRES_USERNAME/g" .env
sed -i -e "s/<MY POSTGRES PASSWORD>/$MY_POSTGRES_PASSWORD/g" .env

printf "%b" "$DONE\n"

# Copy nginx config
printf "%b" "Installing latest ${ORANGE}nginx${NC} config         ... "
get_latest_file "/nginx/peertube" "docker-volume/nginx/peertube"
printf "%b" "$DONE\n"

# Copy docker-compose files
printf "%b" "Installing latest ${ORANGE}compose${NC} file         ... "
get_latest_file "/docker/docker-compose.yml" "docker-compose.yml"
printf "%b" "$DONE\n"

# chown on workdir
printf "%b" "Assigning $WORKDIR ownership      ... "
chown -R docker:docker "$WORKDIR"
printf "%b" "$DONE\n"

# Create / override systemd service
printf "%b" "Generating systemd peertube.service    ... "

cat <<EOT > $SERVICE_PATH
[Unit]
Description=PeerTube daemon
Requires=docker.service
After=docker.service

[Service]
TimeoutStartSec=0
Restart=on-failure
StartLimitBurst=3
User=docker
Group=docker
WorkingDirectory=$WORKDIR
ExecStart=$COMPOSE up
ExecStop=$COMPOSE stop peertube

[Install]
WantedBy=multi-user.target
EOT

printf "%b" "$DONE\n"

# Enable peertube systemd service
printf "%b" "Enabling systemd peertube.service      ... "
systemctl >/dev/null 2>&1 daemon-reload # redirect out possible errors
systemctl >/dev/null 2>&1 enable peertube
printf "%b" "$DONE\n"

# Step 3 - Compose pull
printf "%b" "\nPulling docker images\ \n"
$COMPOSE pull

# Step 4 - Generate the first SSL certificate using Let's Encrypt
printf "%b" "\nGenerating SSL certificate using Let's Encrypt \n"
$CLI certbot:init

# Step 5 - Compose Up
printf "%b" "\nUp docker stack\ \n"
$CLI stack:up
systemctl start --no-block peertube # be sure start process does not block stdout

# Success message
cat <<EOF

                      ______                           _______         _
                 _   (_____ \                         (_______)       | |
  ____  _____  _| |_  _____) ) _____  _____   ____        _     _   _ | |__   _____
 / _  || ___ |(_   _)|  ____/ | ___ || ___ | / ___)      | |   | | | ||  _ \ | ___ |
( (_| || ____|  | |_ | |      | ____|| ____|| |     _    | |   | |_| || |_) )| ____|
 \___ ||_____)   \__)|_|      |_____)|_____)|_|    (_)   |_|   |____/ |____/ |_____)
(_____|


EOF

printf "%b" "${GREEN}The PeerTube docker stack is now successfully installed!${NC}\n"

cat <<EOF

Get your admin credentials and DKIM DNS TXT Record with:

EOF

printf "%b" "  ${ORANGE}$ peertube get-admin-credentials${NC}\n"
printf "%b" "  ${ORANGE}$ peertube postfix:get-dkim-record${NC}\n\n"
}
