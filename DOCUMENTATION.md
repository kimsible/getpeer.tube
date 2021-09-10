# How getpeer.tube works

## Steps

- Check if the script is running as root
- Check if the host works with systemd
- Check if cURL is installed
- Check if **Docker >= v17.06** is installed
- Install or upgrade Compose binary from GitHub Releases
- Create non-root system user owner of working directory
- Create or upgrade CLI

The next steps are done only if there is not any PeerTube docker stack already installed:

- Create working directory `/var/peertube`
- Get latest official compose setup of PeerTube stack from GitHub Raw
  - Generate PostgreSQL credentials
  - Use defined `MY_EMAIL_ADDRESS` and `MY_DOMAIN` and wait for editing updated `.env`
- Create `peertube.service`
- Pull latest images
- Run `peertube.service`
- Display **PeerTube Admin Credentials** once server up or error logs
- Display **PeerTube DKIM DNS TXT Record** to configure into your Domain Name System zone

## Use cases

### Basic usage with cURL

```shell
curl https://getpeer.tube | sh
```

### Advanced usage with env vars

You may want to **auto-fill** environment variables `MY_EMAIL_ADDRESS` and `MY_DOMAIN`:

```shell
MY_EMAIL_ADDRESS=me@domain.tld MY_DOMAIN=domain.tld curl https://getpeer.tube | sh
```

You can also download and run [the script](https://raw.github.com/kimsible/getpeer.tube/master/script/index.sh) manually.


## Extended CLI

### Official Server Tools

You can use all the [official server tools commands](https://docs.joinpeertube.org/maintain-tools?id=server-tools):

```bash
$ peertube parse-log
$ peertube prune-storage
$ peertube update-host
$ peertube reset-password -- -u target_username
$ peertube plugin:install -- --npm-name peertube-plugin-myplugin
...
```

### Backup and Restore

For each backup you'll need to dump the PostreSQL database :

Before backup
```bash
$ peertube postgres:dump /var/peertube/docker-volume/db.tar
```

For each restoration you need to down all container with :

Before restoration
```bash
$ peertube down
```

After restoration
```bash
$ peertube postgres:restore /var/peertube/docker-volume/db.tar
$ peertube up
```

### Migration server to server

On the old server :

```bash
$ peertube postgres:dump /var/peertube/docker-volume/db.tar
$ peertube down
$ rsync -av --exclude docker-volume/db /var/peertube/ username@new-server:/var/peertube/
```

**WARNING**: this command could fail with `docker-volume/opendkim/keys/peertube.*` if you do not have a root access on the old server, in this case, don't worry, you just need to copy them manually. =)

On the new server :
```bash
$ peertube postgres:up
$ peertube postgres:restore /var/peertube/docker-volume/db.tar
$ systemctl start peertube
```

### Automatic upgrade

⚠️ **Before any upgrade**<br>
💡 Don't forget to backup your peertube docker stack.<br>
💡 Edit any configuration file one by one if required by the release.<br>
💡 Check breaking changes here: https://github.com/Chocobozzz/PeerTube/releases

```bash
$ peertube upgrade
```

### Command List

Simply:
```bash
$ peertube # Will display command list
```

Or see https://github.com/kimsible/getpeer.tube/blob/master/cli/peertube.

## Development

```shell
GIT_BRANCH=develop curl https://raw.githubusercontent.com/kimsible/getpeer.tube/master/script/index.sh | sh
```

This error occurs if you have already installed peertube in another working directory.

```
ERROR: Pool overlaps with other one on this address space
```

To solve that issue you need to stop all old running containers and remove all unsused networks created by these old ones.
```shell
docker stop $(docker ps -a -q)
docker network prune
```

Magic command to reset all docker containers, images, volumes and networks.

```shell
docker stop $(docker ps -a -q) & wait; docker rm $(docker ps -a -q) & wait; docker rmi $(docker images -a -q); docker volume rm $(docker volume ls -q) & wait; docker network prune -f
```
