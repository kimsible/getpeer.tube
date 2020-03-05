# Install PeerTube

[ WORK IN PROGRESS ]

Automatic script to **install** or **upgrade** the PeerTube stack based on [the official docker production setup](https://docs.joinpeertube.org/#/install-docker).

Runs on most GNU linux webservers with [Docker](https://docs.docker.com/install/) >= v17.06 and SSH access **as root** or sudoer user with `sudo` prefix.

## Usage
With **cURL**:
```shell
sh -c "$(curl -fsSL https://raw.github.com/kimsible/install-peertube/master/install.sh)"
```
With **Wget**:
```shell
sh -c "$(wget https://raw.github.com/kimsible/install-peertube/master/install.sh -O -)"
```

You also can download and run [the script](https://raw.github.com/kimsible/install-peertube/master/install.sh) manually.

## Steps

- Check if the webserver works with systemd
- Check if Docker >= v17.06 is installed
- Stop `peertube.service` if upgrading
- Install or upgrade Docker Compose binary
- Create working directory `/var/peertube`
- Create a non-root system user owner of working directory
- Get the latest official setup `traefik.toml` (reverse proxy) and `docker-compose.yml` file of PeerTube stack
- Get last Compose `.env` and generate Postgres DB credentials when installing or merge environments variables when upgrading.
- Create or update a systemd service `peertube`
- Pull or upgrade all containers
- Run `peertube.service`
- Display **Admin PeerTube Credentials** once server is up or logs if errors occur

## Known issues

This error occurs if you have already installed peertube in another working directory.

```
ERROR: Pool overlaps with other one on this address space
```

To solve that issue you need to stop all old running containers and remove all unsused networks created by these old ones :
```shell
docker stop $(docker ps -a -q)
docker network prune
```

## Development

Magic command to reset all docker containers, images, volumes and networks :

```shell
docker stop $(docker ps -a -q) & wait; docker rm $(docker ps -a -q) & wait; docker rmi $(docker images -a -q); docker volume rm $(docker volume ls -q) & wait; docker network prune -f
```
