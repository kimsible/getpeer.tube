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
    curl -sSL $PEERTUBE_DOCKER_RAW_URL$remote_path > $local_path
  elif has "wget"; then
    wget -nv $PEERTUBE_DOCKER_RAW_URL$remote_path -O $local_path
  fi
}

# Get docker-compose release from GitHub
get_docker_compose() {
  release=$1
  download_url="https://github.com/docker/compose/releases/download/$release/docker-compose-`uname -s`-`uname -m`"
  if has "curl"; then
    curl -sSL $download_url -o /usr/local/bin/docker-compose
  elif has "wget"; then
    wget -nv $download_url -O /usr/local/bin/docker-compose
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

# Other architectures than x86_64
if [ -z "`uname -a | grep -o "x86_64"`" ]; then
  echo >&2 "Compose Binary can't be installed on your architecture"
  COMPOSE="docker-compose"
  if ! has "$COMPOSE"; then
    echo >&2 "Unfortunately docker-compose is not installed on your system"
    exit 1
  else
    compose_current_release=`get_current_release "$COMPOSE -v"`
    echo >&2 "Using system docker-compose, found version $compose_current_release"
  fi
else
  # Install or upgrade docker-compose
  echo >&2 "Check latest release of Compose on GitHub Releases"
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

# Copy .env
if [ ! -f  ./.env ]; then
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

  # Randomize postgres username and password
  MY_POSTGRES_USERNAME="`head /dev/urandom | tr -dc A-Za-z0-9 | head -c 10`"
  MY_POSTGRES_PASSWORD=`date +%s | sha256sum | base64 | head -c 32`

  # Replace them in .env
  sed -i -e "s/<MY POSTGRES USERNAME>/$MY_POSTGRES_USERNAME/g" .env
  sed -i -e "s/<MY POSTGRES PASSWORD>/$MY_POSTGRES_PASSWORD/g" .env
else
  if [ "$LOCK_COMPOSE_SETUP" = true ] || [ "$LOCK_COMPOSE_ENV" = true ]; then
    echo >&2 "Keep existing environment variables .env"
  else
    echo >&2 "Get latest environment variables .env"
    get_latest_file "/.env" ".env.new"

    # Make sure new .env is well downloaded with patterns to replace
    if [ ! -f ./.env.new ]; then
      echo >&2 "ERROR: Latest .env is missing"
      exit 1
    fi

    # Make sure to find all patterns in new .env
    missing_patterns=0
    if [ -z "`grep -E -o "<MY EMAIL ADDRESS>" .env.new`" ]; then
      missing_patterns=1
      echo >&2 "ERROR: Pattern <MY EMAIL ADDRESS> is missing in latest .env"
    fi
    if [ -z "`grep -E -o "<MY DOMAIN>" .env.new`" ]; then
      missing_patterns=1
      echo >&2 "ERROR: Pattern <MY DOMAIN> is missing in latest .env"
    fi
    if [ -z "`grep -E -o "<MY POSTGRES USERNAME>" .env.new`" ]; then
      missing_patterns=1
      echo >&2 "ERROR: Pattern <MY POSTGRES USERNAME> is missing in latest .env"
    fi
    if [ -z "`grep -E -o "<MY POSTGRES PASSWORD>" .env.new`" ]; then
      missing_patterns=1
      echo >&2 "ERROR: Pattern <MY POSTGRES PASSWORD> is missing in latest .env"
    fi

    # Exit script if at least one pattern is missing
    if [ "$missing_patterns" -ne 0 ]; then exit 1; fi

    # Automatic filling new .env
    # Replace .env variables with MY_EMAIL_ADDRESS, MY_DOMAIN, MY_POSTGRES_USERNAME and MY_POSTGRES_PASSWORD
    sed -i -e "s/<MY POSTGRES DB>/peertube/g" .env.new
    if [ ! -z $MY_EMAIL_ADDRESS ]; then
      sed -i -e "s/<MY EMAIL ADDRESS>/$MY_EMAIL_ADDRESS/g" .env.new
    fi
    if [ ! -z $MY_DOMAIN ]; then
      sed -i -e "s/<MY DOMAIN>/$MY_DOMAIN/g" .env.new
    fi

    # Get postgres username and password from existing PEERTUBE_DB_USERNAME and PEERTUBE_DB_PASSWORD in .env
    MY_POSTGRES_USERNAME="`grep -E -o "PEERTUBE_DB_USERNAME=.*" ./.env | sed -E "s/PEERTUBE_DB_USERNAME=//g"`"
    MY_POSTGRES_PASSWORD="`grep -E -o "PEERTUBE_DB_PASSWORD=.*" ./.env | sed -E "s/PEERTUBE_DB_PASSWORD=//g"`"

    # If credentials not found exit script
    if [ -z "$MY_POSTGRES_USERNAME" ] || [ -z "$MY_POSTGRES_PASSWORD" ]; then
      echo >&2 "ERROR: PostgreSQL credentials are missing in current .env"
      exit 1
    fi

    # Replace them in new .env
    sed -i -e "s/<MY POSTGRES USERNAME>/$MY_POSTGRES_USERNAME/g" .env.new
    sed -i -e "s/<MY POSTGRES PASSWORD>/$MY_POSTGRES_PASSWORD/g" .env.new

    # Now everything is ok, overwrite old .env with the new one
    mv .env.new .env
  fi
fi

# Copy traefik.toml
if [ ! -f ./docker-volume/traefik/traefik.toml ] || [ ! "$LOCK_COMPOSE_SETUP" ] && [ ! "$LOCK_TRAEFIK_CONFIG" ]; then
  echo >&2 "Get latest reverse-proxy config docker-volume/traefik/traefik.toml"
  get_latest_file "/config/traefik.toml" "docker-volume/traefik/traefik.toml"
else
  echo >&2 "Keep existing reverse-proxy config docker-volume/traefik/traefik.toml"
fi

# Copy docker-compose.yml
if [ ! -f ./docker-compose.yml ] || [ ! "$LOCK_COMPOSE_SETUP" ] && [ ! "$LOCK_COMPOSE_FILE" ]; then
  echo >&2 "Get latest docker-compose.yml"
  get_latest_file "/docker-compose.yml" "docker-compose.yml"
else
  echo >&2 "Keep existing docker-compose.yml"
fi

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

# If MY_EMAIL_ADDRESS and MY_DOMAIN are not defined edit .env
if [ -z $MY_EMAIL_ADDRESS ] || [ -z $MY_DOMAIN ]; then
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

# Pull docker containers
echo >&2 "Pull Docker containers..."
$COMPOSE >&2 pull

# Enable peertube systemd service
systemctl >/dev/null 2>&1 dameon-reload # redirect out possible errors
systemctl >&2 enable peertube

# Run one time before starting service
echo >&2 "Start PeerTube service"

# Run compose detached and exit if any errors
compose_errors=`$($COMPOSE up -d) | grep -i 'ERROR'`
if [ ! -z "$compose_errors" ]; then
  exit 1
fi

# Block stdout until server is up
echo >&2 "Wait until PeerTube server is up..."
sleep 50s &
while [ -z "`$COMPOSE logs --tail=2 peertube | grep -o 'Server listening on'`" ]; do
  # Break if any stack errors occur
  # Displays errors and exit
  stack_errors=`$COMPOSE logs --tail=40 peertube | grep -i 'error'`
  if [ ! -z "$stack_errors" ]; then
    echo >&2 $stack_errors
    exit 1
  fi
  # Break after 50s / until pid of "sleep 50s" is destroyed
  # Display logs and exit
  if [ -z "`ps -ef | grep $! | grep -o -E 'sleep 50s'`" ]; then
    $COMPOSE logs --tail=40 peertube
    exit 1
  fi
done
echo >&2 "PeerTube server is successfully up"

# Start service
systemctl start --no-block peertube # be sure start process does not block stdout

# Display Admin Credentials
echo >&2 ""
echo >&2 "> PeerTube Admin Credentials <"
username=`$COMPOSE logs peertube | grep -A1 -E -o "Username: [0-9a-zAZ-Z]*"`
password=`$COMPOSE logs peertube | grep -A1 -E -o "User password: [0-9a-zAZ-Z]*"`

if [ ! -z "$username" ] && [ ! -z "$password" ]; then
  echo >&2 $username
  echo >&2 $password
# If credentials are not found in compose logs
else
  if [ ! -f docker-volume/data/logs/peertube.log ]; then
    echo >&2 "ERROR: Can't display Admin Credentials, missing docker-volume/data/logs/peertube.log"
    exit 1
  else
    username=`cat docker-volume/data/logs/peertube.log | grep -A1 -E -o "Username: [0-9a-zAZ-Z]*"`
    password=`cat docker-volume/data/logs/peertube.log | grep -A1 -E -o "User password: [0-9a-zAZ-Z]*"`

    if [ ! -z "$username" ] && [ ! -z "$password" ]; then
      echo >&2 $username
      echo >&2 $password
    else
      echo >&2 "ERROR: Missing Admin Credentials in logs"
      exit 1
    fi
  fi
fi
}
