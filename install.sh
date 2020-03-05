#!/usr/bin/env sh

{
#################
### CONSTANTS ###
#################

# Peertube: https raw url of docker production PeerTube setup
PEERTUBE_DOCKER_RAW_URL=https://raw.githubusercontent.com/chocobozzz/PeerTube/develop/support/docker/production

# Docker: needs version matching with v3.3 Compose file format
# https://docs.docker.com/compose/compose-file/compose-versioning/
DOCKER_PREREQUISITE_VERSION_NUMBER=17.06

# Docker Compose binary path
COMPOSE=/usr/local/bin/docker-compose

# PeerTube Working directory
WORKDIR=/var/peertube

# PeerTube Service Path
SERVICE_PATH=/etc/systemd/system/peertube.service


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
    curl -sL $PEERTUBE_DOCKER_RAW_URL$remote_path > $local_path
  elif has "wget"; then
    wget -q $PEERTUBE_DOCKER_RAW_URL$remote_path -O $local_path
  fi
}

# Get docker-compose release from GitHub
get_docker_compose() {
  release=$1
  download_url="https://github.com/docker/compose/releases/download/$release/docker-compose-`uname -s`-`uname -m`"
  if has "curl"; then
    curl -sL $download_url -o /usr/local/bin/docker-compose
  elif has "wget"; then
    wget -q $download_url -O /usr/local/bin/docker-compose
  fi
  chmod +x /usr/local/bin/docker-compose
}

# Get latest release name from GitHub api
get_latest_release_name() {
  repo=$1
  api_url="https://api.github.com/repos/$repo/releases/latest"
  if has "curl"; then
    curl -s $api_url |
      grep '"tag_name":' |         # Get tag line
      sed -E 's/.*"([^"]+)".*/\1/' # Pluck JSON value
  elif has "wget"; then
    wget -qO- $api_url |
      grep '"tag_name":' |
      sed -E 's/.*"([^"]+)".*/\1/'
  fi
}

get_release_version_number() {
  release=$1
  version_number=`echo "${release%.*}"`
  echo "$version_number" | sed 's/v//g' # Remove prefix "v"
}

get_release_patch_number() {
  release=$1
  echo "${release##*.}"
}

is_update() {
  current_release=$1
  latest_release=$2
  current_version_number=`get_release_version_number "$current_release"`
  latest_version_number=`get_release_version_number "$latest_release"`
  if [ "$current_version_number" = "$latest_version_number" ]; then
    current_patch_number=`get_release_patch_number "$current_release"`
    latest_patch_number=`get_release_patch_number "$latest_release"`
    # Patch to upgrade return 1, nothing to upgrade return 0
    [ $(echo "$latest_patch_number < $current_patch_number" | bc -l) = 0 ] && true
  else
    # Version (minor or major) to upgrade return 1, nothing to upgrade return 0
    [ $(echo "$latest_version_number < $current_version_number" | bc -l) = 0 ] && true
  fi
}

get_current_release() {
  command=$1
  echo `$command` | grep -o -E "[0-9]{1,3}\.[0-9]{1,3}\.[0-9]{1,3}"
}

check_prerequisite_version() {
  current_release=$1
  prerequisite_version_number=$2
  current_version_number=`get_release_version_number "$current_release"`
  # Prerequisite greater return 1, lower or equal return 0
  [ $(echo "$current_version_number < $prerequisite_version_number" | bc -l) = 0 ] && true
}


#################
##### MAIN ######
#################
echo >&2 "> Get latest PeerTube Docker setup into $WORKDIR <"

echo >&2 "Prerequisites"
missing_prerequisites=0

# root
uid=`id -u`
if [ "$uid" -ne 0 ]; then
  missing_prerequisites=1
  echo >&2 "- this script must be run as root or as a sudoer user with sudo"
else
  echo >&2 "- root OK"
fi

# systemd
if ! has "systemctl"; then
  missing_prerequisites=1
  echo >&2 "- systemd is missing"
else
  echo >&2 "- systemd OK"
fi

# curl or wget
if ! has "curl" && ! has "wget"; then
  missing_prerequisites=1
  echo >&2 "- curl or wget are required, both are missing"
else
  echo >&2 "- curl / wget OK"
fi

# docker
if ! has "docker"; then
  missing_prerequisites=1
  echo >&2 "- docker >= $DOCKER_PREREQUISITE_VERSION_NUMBER is missing"
else
  docker_current_release=`get_current_release "docker -v"`
  if ! check_prerequisite_version "$docker_current_release" "$DOCKER_PREREQUISITE_VERSION_NUMBER"; then
    missing_prerequisites=1
    echo >&2 "- docker >= $DOCKER_PREREQUISITE_VERSION_NUMBER is required, found $docker_current_release"
  else
    echo >&2 "- docker OK"
  fi
fi

# Exit if not all prerequisites
if [ "$missing_prerequisites" -ne 0 ]; then exit 1; fi

# Docker: make sure a non-root docker user system exists
echo >&2 "Create non-root system user (useradd -r -M -g docker docker) if non-exists"
useradd >/dev/null 2>&1 -r -M -g docker docker # redirect out message if user already exists

# Stop active peertube service to not conflict upgrade
if [ -f "$SERVICE_PATCH" ]; then
  if [ "`systemctl is-active peertube`"="active" ]; then
    echo >&2 "Stop existing PeerTube service to not conflict upgrade"
    systemctl >&2 stop peertube
  fi
fi

# Install or upgrade docker-compose
compose_latest_release=`get_latest_release_name "docker/compose"`
if ! has "$COMPOSE"; then
  echo >&2 "Install Docker Compose $compose_latest_release"
  get_docker_compose "$compose_latest_release"
else
  compose_current_release=`get_current_release "$COMPOSE -v"`
  if ! is_update "$compose_current_release" "$compose_latest_release"; then
    echo >&2 "Upgrade Docker Compose from "$compose_current_release" to $compose_latest_release"
    get_docker_compose "$compose_latest_release"
  fi
fi

# Init workdir
echo >&2 "Create workdir $WORKDIR if non-exists"
mkdir -p "$WORKDIR"
cd "$WORKDIR"

# Init docker-volume and traefik directory
echo >&2 "Create docker-volume/traefik if non-exists"
mkdir -p docker-volume/traefik

# Create traefik acme config
echo >&2 "Create docker-volume/traefik/acme.json if non-exists"
touch docker-volume/traefik/acme.json
chmod 600 docker-volume/traefik/acme.json

# If .env does not exist get the lastest one
if [ -f  ./.env ]; then
  echo >&2 "Keep existing .env"
else
  # Copy .env
  echo >&2 "Get latest environment variables .env"
  get_latest_file "/.env" ".env"

  # Automatic filling .env
  # Replace .env variables with MY_EMAIL_ADDRESS, MY_DOMAIN, MY_POSTGRES_USERNAME and MY_POSTGRES_PASSWORD
  sed -i -e "s/<MY POSTGRES DB>/peertube/g" .env
  if [ ! -z $MY_EMAIL_ADDRESS ]; then
    sed -i -e "s/<MY EMAIL ADDRESS>/$MY_EMAIL_ADDRESS/g" .env
  fi
  if [ ! -z $MY_DOMAIN ]; then
    sed -i -e "s/<MY DOMAIN>/$MY_DOMAIN/g" .env
  fi
  # Randomize postgres username
  MY_POSTGRES_USERNAME="`head /dev/urandom | tr -dc A-Za-z0-9 | head -c 10`"
  sed -i -e "s/<MY POSTGRES USERNAME>/$MY_POSTGRES_USERNAME/g" .env
  # Randomize postgres password
  MY_POSTGRES_PASSWORD=`date +%s | sha256sum | base64 | head -c 32`
  sed -i -e "s/<MY POSTGRES PASSWORD>/$MY_POSTGRES_PASSWORD/g" .env
fi

# Copy traefik config
echo >&2 "Get latest reverse proxy docker-volume/traefik/traefik.toml"
get_latest_file "/config/traefik.toml" "docker-volume/traefik/traefik.toml"

# Copy docker-compose
echo >&2 "Get latest docker-compose.yml"
get_latest_file "/docker-compose.yml" "docker-compose.yml"

# chown on workdir
echo >&2 "Set non-root system user as owner of workdir (chown -R docker:docker $WORKDIR)"
chown -R docker:docker "$WORKDIR"

# Create / Update systemd service
if [ ! -f $SERVICE_PATH ]; then
  echo >&2 "Create $SERVICE_PATH"
else
  echo >&2 "Update $SERVICE_PATH"
fi
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
ExecStop=$COMPOSE down

[Install]
WantedBy=multi-user.target
EOT

# If admin email and domain are not defined as parameters edit .env
if [ -z $MY_EMAIL_ADDRESS ]; then
  if [ -z $MY_DOMAIN ]; then
    echo >&2 "Edit .env ..."
    sleep 1

    if has "nano"; then
      exec nano < /dev/tty "$@" ./.env & wait
    elif has "vim"; then
      exec vim < /dev/tty "$@" ./.env & wait
    elif has "vi"; then
      exec vi < /dev/tty "$@" ./.env & wait
    else
      echo >&2 "- missing command-line editor nano, vim or vi"
    fi
  fi
fi

# Pull docker containers
echo >&2 "Pull Docker containers..."
$COMPOSE >&2 pull

# Enable peertube systemd service
systemctl >/dev/null 2>&1 dameon-reload # redirect out possible errors
systemctl >&2 enable peertube

# Start service
echo >&2 "Start PeerTube service"
systemctl start --no-block peertube # be sure start process does not block stdout

# Block stdout until server is up
echo >&2 "Wait until PeerTube server is up..."
sleep 12s &
while [ -z "`$COMPOSE logs --tail=2 peertube | grep -o 'Server listening on'`" ]; do
  # Break after 12s / until pid of "sleep 12s" is destroyed
  # Display journalctl error logs and exit
  if [ -z "`ps -ef | grep $! | grep -o -E 'sleep 12s'`" ]; then
    journalctl -q -e -u peertube | grep -i "error" || [ "`systemctl is-active peertube`" = "failed" ] && $COMPOSE up
    exit 1
  fi
done

# if compose log file is not created display journalctl error logs and exit
if [ ! -f docker-volume/data/logs/peertube.log ]; then
  journalctl -q -e -u peertube | grep -i "error" || [ "`systemctl is-active peertube`" = "failed" ] && $COMPOSE up
  exit 1
fi

# Display Admin Credentials
echo >&2 ""
echo >&2 "> PeerTube Admin Credentials <"
echo >&2 `cat docker-volume/data/logs/peertube.log | grep -A1 -E -o "Username: [0-9a-zAZ-Z]*"`
echo >&2 `cat docker-volume/data/logs/peertube.log | grep -A1 -E -o "User password: [0-9a-zAZ-Z]*"`
}
