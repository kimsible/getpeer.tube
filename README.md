# Install PeerTube

**Installing** and **upgrading** of the [PeerTube](https://joinpeertube.org) stack with one SHELL command.

This script is based on [the official docker production setup](https://docs.joinpeertube.org/#/install-docker) and runs on most x86-64 linux distributions.

### Server requirements

- x86-64 Linux Distribution updated
- SSH access **as root** or sudoer user with `sudo` prefix
- Access on **ports 25 (smtp)**, **80 (http)** and **443 (https)**
- **[Docker](https://docs.docker.com/install/) >= v17.06**

## Usage

Basic usage with **cURL** or **Wget**.
```shell
sh -c "$(curl -fsSL https://raw.github.com/kimsible/install-peertube/master/install.sh)"
```
```shell
sh -c "$(wget https://raw.github.com/kimsible/install-peertube/master/install.sh -O -)"
```

**Automatic filling** of environment variables `MY_EMAIL_ADDRESS` and `MY_DOMAIN`.
```shell
MY_EMAIL_ADDRESS=me@domain.tld MY_DOMAIN=domain.tld \
sh -c "$(curl -fsSL https://raw.github.com/kimsible/install-peertube/master/install.sh)"
```
```shell
MY_EMAIL_ADDRESS=me@domain.tld MY_DOMAIN=domain.tld \
sh -c "$(wget https://raw.github.com/kimsible/install-peertube/master/install.sh -O -)"
```

Prevent **Custom Compose Setup** from updating.
```shell
LOCK_COMPOSE_SETUP=true \
sh -c "$(curl -fsSL https://raw.github.com/kimsible/install-peertube/master/install.sh)"
```
```shell
LOCK_COMPOSE_SETUP=true \
sh -c "$(wget https://raw.github.com/kimsible/install-peertube/master/install.sh -O -)"
```

You can also download and run [the script](https://raw.github.com/kimsible/install-peertube/master/install.sh) manually.

## Steps

- Check if the script is running as root
- Check if the host works with systemd
- Check if cURL or Wget are installed
- Check if **Docker >= v17.06** is installed
- Stop existing `peertube.service`
- Install or upgrade Compose binary from GitHub Releases
- Create working directory `/var/peertube`
- Create non-root system user owner of working directory
- Get latest official compose setup of PeerTube stack from GitHub Raw
  - Generate or use existing PostgreSQL credentials
  - Use defined `MY_EMAIL_ADDRESS` and `MY_DOMAIN` or wait for editing updated `.env`
  - Prevent Custom Compose Setup from updating if `LOCK_COMPOSE_SETUP` is defined
  - Prevent `.env` from updating if `LOCK_COMPOSE_ENV` is defined
  - Prevent `docker-compose.yml` from updating if `LOCK_COMPOSE_FILE` is defined
  - Prevent `traefik.toml` from updating if `LOCK_TRAEFIK_CONFIG` is defined
- Create or update `peertube.service`
- Pull latest images
- Run `peertube.service`
- Display **Admin PeerTube Credentials** once server up or error logs

## Known issues

This error occurs if you have already installed peertube in another working directory.

```
ERROR: Pool overlaps with other one on this address space
```

To solve that issue you need to stop all old running containers and remove all unsused networks created by these old ones.
```shell
docker stop $(docker ps -a -q)
docker network prune
```

## Development

Magic command to reset all docker containers, images, volumes and networks.

```shell
docker stop $(docker ps -a -q) & wait; docker rm $(docker ps -a -q) & wait; docker rmi $(docker images -a -q); docker volume rm $(docker volume ls -q) & wait; docker network prune -f
```
