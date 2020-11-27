#!/usr/bin/env sh

{
#################
### CONSTANTS ###
#################

# Default branch
if [ ! "$GIT_BRANCH" ]; then
  GIT_BRANCH="master"
fi

# Peertube: https raw url of docker production PeerTube setup
PEERTUBE_DOCKER_RAW_URL=https://raw.githubusercontent.com/kimsible/install-peertube/$GIT_BRANCH

# Docker: needs version matching with v3.3 Compose file format
# https://docs.docker.com/compose/compose-file/compose-versioning/
DOCKER_PREREQUISITE_RELEASE=17.06.01

# Docker Compose binary path
COMPOSE=/usr/local/bin/docker-compose

# PeerTube Working directory
WORKDIR=/var/peertube

# PeerTube CLI binary path
CLI=/usr/sbin/peertube

# PeerTube Archive Dump for upgrade
DB_DUMP=/tmp/peertube-db-dump.tar

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

# Get latest file from GitHub raw
get_latest_file() {
  remote_path=$1
  local_path=$2

  if has "curl"; then
    curl -#fL $PEERTUBE_DOCKER_RAW_URL$remote_path -o $local_path 2>&1 || (echo "Request URL: $PEERTUBE_DOCKER_RAW_URL$remote_path" && exit 1)
  elif has "wget"; then
    wget -nv $PEERTUBE_DOCKER_RAW_URL$remote_path -O $local_path 2>&1 || (echo "Request URL: $PEERTUBE_DOCKER_RAW_URL$remote_path" && exit 1)
  fi
}

# Get docker-compose release from GitHub
get_docker_compose() {
  release=$1
  download_url="https://github.com/docker/compose/releases/download/$release/docker-compose-`uname -s`-`uname -m`"
  if has "curl"; then
    curl -#fL $download_url -o /usr/local/bin/docker-compose 2>&1 || exit 1
  elif has "wget"; then
    wget -nv $download_url -O /usr/local/bin/docker-compose 2>&1 || exit 1
  fi
  chmod +x /usr/local/bin/docker-compose
}

# Get latest release name from GitHub api
get_latest_release_name() {
  repo=$1
  api_url="https://api.github.com/repos/$repo/releases/latest"
  if has "curl"; then
    curl -sL $api_url |
      grep '"tag_name":' |         # Get tag line
      sed -E 's/.*"([^"]+)".*/\1/' # Pluck JSON value
  elif has "wget"; then
    wget -qO- $api_url |
      grep '"tag_name":' |
      sed -E 's/.*"([^"]+)".*/\1/'
  fi
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
  echo `$command` | grep -o -E "[0-9]{1,3}\.[0-9]{1,3}\.[0-9]{1,3}"
}

get_env_var() {
  echo `grep -E -o "^$1=.*" ./.env | sed -E "s/$1=//g"`
}

#################
##### MAIN ######
#################

echo "Prerequisites #"
missing_prerequisites=0

# root
uid=`id -u`
if [ "$uid" -ne 0 ]; then
  missing_prerequisites=1
  echo "- $ERROR: this script must be run as root or as a sudoer user with sudo"
else
  echo "- root $OK"
fi

# systemd
if ! has "systemctl"; then
  missing_prerequisites=1
  echo "- $ERROR:systemd is missing"
else
  echo "- systemd $OK"
fi

# curl or wget
if ! has "curl" && ! has "wget"; then
  missing_prerequisites=1
  echo "- $ERROR: curl or wget are required, both are missing"
else
  echo "- curl / wget $OK"
fi

# docker
if ! has "docker"; then
  missing_prerequisites=1
  echo "- $ERROR: docker >= $DOCKER_PREREQUISITE_RELEASE is missing"
else
  docker_current_release=`get_current_release "docker -v"`
  if ! is_update "$docker_current_release" "$DOCKER_PREREQUISITE_RELEASE"; then
    missing_prerequisites=1
    echo "- $ERROR: docker >= $DOCKER_PREREQUISITE_RELEASE is required, found $docker_current_release"
  else
    echo "- docker $OK"
  fi
fi

# Exit if not all prerequisites
if [ "$missing_prerequisites" -ne 0 ]; then exit 1; fi

# Docker: make sure a non-root docker user system exists
echo -n "Create non-root system user (useradd -r -M -g docker docker) if non-exists ..."
useradd >/dev/null 2>&1 -r -M -g docker docker # redirect out message if user already exists
echo $DONE

# Other architectures than x86_64
if [ -z "`uname -a | grep -o "x86_64"`" ]; then
  echo "$WARNING: Compose Binary can't be installed on your architecture"
  COMPOSE="docker-compose"
  if ! has "$COMPOSE"; then
    echo "$ERROR: Unfortunately docker-compose is not installed on your system"
    exit 1
  else
    compose_current_release=`get_current_release "$COMPOSE -v"`
    echo "Using system docker-compose, found version $compose_current_release"
  fi
else
  # Install or upgrade docker-compose
  echo -n "Check latest release of Compose on GitHub Releases ..."
  compose_latest_release=`get_latest_release_name "docker/compose"`
  echo $DONE

  if ! has "$COMPOSE"; then
    echo "Install Docker Compose $compose_latest_release #"
    get_docker_compose "$compose_latest_release"
  else
    compose_current_release=`get_current_release "$COMPOSE -v"`

    if ! is_update "$compose_current_release" "$compose_latest_release"; then
      echo "Upgrade Docker Compose from "$compose_current_release" to $compose_latest_release #"
      get_docker_compose "$compose_latest_release"
    else
      echo "Nothing to update, using docker-compose found version $compose_current_release"
    fi
  fi
fi

# Init workdir
echo -n "Create workdir $WORKDIR if non-exists ..."
mkdir -p "$WORKDIR/docker-volume"
cd "$WORKDIR"
echo $DONE

# Get latest peertube cli
echo "Get latest peertube cli #"
rm -f $CLI
get_latest_file "/cli/peertube" "$CLI"
chmod +x $CLI

# Dump existing database to easier migrate if any PostgreSQL version upgrade
# To proceed, a full Compose setup and a mounted database must exist (docker-volume/db, .env, docker-compose.yml)
if [ -d docker-volume/db ] && [ -f .env ] && [ -f docker-compose.yml ]; then
  # Up PostgreSQL container
  echo "Up PostgreSQL if down #"
  $CLI postgres:up

  # Dump existing database
  echo "Dump PostgreSQL to easier migrate #"
  $CLI postgres:dump $DB_DUMP
fi

# Down all containers to not conflict upgrade
if [ -f .env ] && [ -f docker-compose.yml ]; then
  echo "Down all containers to not conflict upgrade #"
  $CLI down
fi

# Init docker-volume and traefik directory
echo -n "Create docker-volume/traefik if non-exists ..."
mkdir -p docker-volume/traefik
echo $DONE

# Create traefik acme config
echo -n "Create docker-volume/traefik/acme.json if non-exists ..."
touch docker-volume/traefik/acme.json
chmod 600 docker-volume/traefik/acme.json
echo $DONE

# Init nginx directory
echo -n "Create docker-volume/nginx if non-exists ..."
mkdir -p docker-volume/nginx
echo $DONE

if [ -f .env ]; then # If .env exists keep existing environment variables
  echo -n "Get existing PostgreSQL credentials in .env file ..."
  MY_POSTGRES_USERNAME="`get_env_var 'PEERTUBE_DB_USERNAME'`"
  MY_POSTGRES_PASSWORD="`get_env_var 'PEERTUBE_DB_PASSWORD'`"
  echo $DONE

  # Exit if PostgreSQL credentials not found
  if [ -z $MY_POSTGRES_USERNAME ] && [ -z $MY_POSTGRES_PASSWORD ]; then
    echo "\n$ERROR: PostgreSQL username or password not found in $WORKDIR/.env, can't upgrade"
    exit 1
  fi

  # Get email and domain
  echo -n "Get existing email and domain in .env file ..."
  MY_EMAIL_ADDRESS="`get_env_var 'PEERTUBE_ADMIN_EMAIL'`"
  MY_DOMAIN="`get_env_var 'PEERTUBE_WEBSERVER_HOSTNAME'`"
  echo $DONE

  [ -z $MY_EMAIL_ADDRESS ] && echo "$WARNING: admin email not found in $WORKDIR/.env"
  [ -z $MY_DOMAIN ] && echo "$WARNING: domain not found in $WORKDIR/.env"
else # If not randomize PostgreSQL username and password
  echo -n "Randomize PostgreSQL credentials ..."

  MY_POSTGRES_USERNAME="`head /dev/urandom | tr -dc A-Za-z0-9 | head -c 10`"
  MY_POSTGRES_PASSWORD=`date +%s | sha256sum | base64 | head -c 32`

  echo $DONE

  [ -z $MY_EMAIL_ADDRESS ] && echo "$WARNING: MY_EMAIL_ADDRESS is not defined"
  [ -z $MY_DOMAIN ] && echo "$WARNING: MY_DOMAIN is not defined"
fi

# Display used environment variables
[ ! -z $MY_EMAIL_ADDRESS ] && echo "Using MY_EMAIL_ADDRESS=$MY_EMAIL_ADDRESS $OK"
[ ! -z $MY_DOMAIN ] && echo "Using MY_DOMAIN=$MY_DOMAIN $OK"

# Create / override .env
echo -n "Generate .env file ..."

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
TRAEFIK_ACME_EMAIL=<MY EMAIL ADDRESS>
TRAEFIK_ACME_DOMAINS=<MY DOMAIN>
EOT

# Auto-fill .env file
sed -i -e "s/<MY EMAIL ADDRESS>/$MY_EMAIL_ADDRESS/g" .env
sed -i -e "s/<MY DOMAIN>/$MY_DOMAIN/g" .env
sed -i -e "s/<MY POSTGRES USERNAME>/$MY_POSTGRES_USERNAME/g" .env
sed -i -e "s/<MY POSTGRES PASSWORD>/$MY_POSTGRES_PASSWORD/g" .env

echo $DONE

# If MY_EMAIL_ADDRESS and MY_DOMAIN are not defined edit .env
if [ -z $MY_EMAIL_ADDRESS ] || [ -z $MY_DOMAIN ]; then
  echo -n "Edit .env ..."
  sleep 1

  if has "nano"; then
    exec nano < /dev/tty "$@" ./.env & wait
    echo $DONE
  elif has "vim"; then
    exec vim < /dev/tty "$@" ./.env & wait
    echo $DONE
  elif has "vi"; then
    exec vi < /dev/tty "$@" ./.env & wait
    echo $DONE
  else
    echo "\n$ERROR: missing command-line editor nano, vim or vi"
    exit 1
  fi
fi

# Copy traefik config
echo "Get latest reverse-proxy traefik config #"
get_latest_file "/traefik/traefik.toml" "docker-volume/traefik/traefik.toml"

# Copy nginx config
echo "Get latest webserver nginx config #"
get_latest_file "/nginx/peertube" "docker-volume/nginx/peertube"

# Copy nginx docker
echo "Get latest nginx docker image #"
get_latest_file "/docker/Dockerfile.nginx" "Dockerfile.nginx"
get_latest_file "/docker/entrypoint.nginx.sh" "entrypoint.nginx.sh"

# Copy docker-compose files
echo "Get latest docker-compose files #"
get_latest_file "/docker/docker-compose.traefik.yml" "docker-compose.traefik.yml"
get_latest_file "/docker/docker-compose.yml" "docker-compose.yml"

# chown on workdir
echo -n "Set non-root system user as owner of workdir (chown -R docker:docker $WORKDIR) ..."
chown -R docker:docker "$WORKDIR"
echo $DONE

# Create / override systemd service
echo -n "Generate $SERVICE_PATH ..."

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
ExecStart=$COMPOSE -f docker-compose.yml -f docker-compose.traefik.yml up
ExecStop=$COMPOSE stop peertube

[Install]
WantedBy=multi-user.target
EOT

echo $DONE

# Enable peertube systemd service
systemctl >/dev/null 2>&1 dameon-reload # redirect out possible errors
systemctl enable peertube

# Re-init existing database before starting peertube systemd service
if [ -f $DB_DUMP ]; then
  # Remove db files
  echo -n "Remove PosgreSQL mounted volume ..."
  rm -rf ./docker-volume/db
  echo $DONE

  # Up postgres service
  echo "Up PostgreSQL to restore dump #"
  $CLI postgres:up

  # Run restore command
  echo "Restore PostgreSQL dump #"
  $CLI postgres:restore $DB_DUMP

  # Clean database archive dump
  echo -n "Clean PostgreSQL dump ..."
  rm -f $DB_DUMP
  echo $DONE
fi

# Compose Up
echo "\nStart PeerTube #"
$CLI up
systemctl start --no-block peertube # be sure start process does not block stdout

# Display Admin Credentials
echo "\nPeerTube Admin Credentials #"
$CLI show-admin

# Display DKIM DNS TXT Record
echo "\nPeerTube DKIM DNS TXT Record #"
$CLI show-dkim
}
