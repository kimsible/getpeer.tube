# Install PeerTube

**Installing** and **upgrading** of the [PeerTube](https://joinpeertube.org) stack with one SHELL command.

This script is based on [the official docker production setup](https://docs.joinpeertube.org/#/install-docker) and runs on most x86-64 linux distributions.

### Server requirements

- x86-64 Linux Distribution updated
- SSH access **as root** or sudoer user with `sudo` prefix
- Access on **port 25 (smtp)**, **port 80 (http)** and **port 443 (https)**
- A Domain Name pointing to this server
- **[Docker](https://docs.docker.com/install/) >= v17.06**

## Usage

Basic usage with **cURL** or **Wget**.
```shell
sh -c "$(curl -fsSL https://raw.github.com/kimsible/install-peertube/master/install.sh)"
```
```shell
sh -c "$(wget https://raw.github.com/kimsible/install-peertube/master/install.sh -O -)"
```

An upgrade will **auto-fill** environment variables `MY_EMAIL_ADDRESS` and `MY_DOMAIN`, when install you'll need to define them :

```shell
MY_EMAIL_ADDRESS=me@domain.tld MY_DOMAIN=domain.tld \
sh -c "$(curl -fsSL https://raw.github.com/kimsible/install-peertube/master/install.sh)"
```
```shell
MY_EMAIL_ADDRESS=me@domain.tld MY_DOMAIN=domain.tld \
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
- Create or update `peertube.service`
- Pull latest images
- Run `peertube.service`
- Display **PeerTube Admin Credentials** once server up or error logs
- Display **PeerTube DKIM DNS TXT Record** to configure into your Domain Name System zone

## Backup / Restore

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


### Mirror Backup

The mirror backup may be between your production server and a remote cloud / FTP.

Production server requirements: `rsync` and `sshpass`.

Backup command

```bash
$ rsync -av --delete --ignore-times --exclude docker-volume/db /var/peertube/ username@remote-cloud:<backups-absolute-path>/var/peertube/
```

To include the backup command in a script without password prompt, you might use sshpass before :
```bash
$ sshpass -p yourpassword rsync -av --exclude docker-volume/db /var/peertube/ username@remote-cloud:<backups-absolute-path>/var/peertube/ --delete
```

#### Basic Restore command only for missing files

```bash
$ rsync -av --delete username@remote-cloud:<backups-absolute-path>/var/peertube/ /var/peertube/
```

#### Full Restore command

```bash
$ rsync -av --delete --ignore-times username@remote-cloud:<backups-absolute-path>/var/peertube /var/peertube
```

For specific protocol without rsync or SSH support like FTP, you might use [rclone](https://rclone.org/ftp/).

#### Crontab

- Edit crontab with `crontab -u root -e`
- Add this line to run it as docker user every day at 5:25am :

```bash
25 5  * * * /usr/bin/peertube-mirror
```

### Incremential Backup

The incremential backup maybe between a local OrangePi / RaspberryPi with a connected external disk and the remote production server.

Local OPI/ RPI requirements : `rsync`, `open-ssh` and  `rsnapshot`.

#### **Operating system - fstab**

First of all your need to configure :

- OPI / RPI connected to internet and with a local SSH access;

- External disk to `fstab` mounted on a home sub-directory :

Get UUID of your disk:
```bash
$ blkid
# /dev/sda1: UUID="7610ebc5-5231-4b59-830e-a9sacb84a" TYPE="ext4" PARTUUID="62a1e04b-b700-fc4e-5878-78863daf9b34"
```
Insert the line bellow into `/etc/fstab`
```
UUID=<UUID> <mounted-disk-absolute-path> auto    rw,user,auto    0    0
```


#### **SSH keys**

On local OPI / RPI, generate SSH keys:

```bash
$ ssh-keygen -t rsa
```

At last copy generated SSH keys from local OPI / RPI to the remote production server:
```bash
$ ssh-copy-id <user>@<remote-production>
```


#### **Rsnapshot config**
On local OPI / RPI, you need to configure rsnapshot.

Before, you may backup the original configuration:

```bash
$ mv /etc/rsnapshot.conf /etc/rsnapshot.conf.backup
```

And put this configuration into `/etc/rsnapshot.conf` :

_Carefull, the space between args are tabs_
```
config_version  1.2
snapshot_root   <mounted-disk-absolute-path>
cmd_cp    /bin/cp
cmd_rm    /bin/rm
cmd_rsync   /usr/bin/rsync
cmd_ssh   /usr/bin/ssh
cmd_logger    /usr/bin/logger
cmd_du    /usr/bin/du
cmd_rsnapshot_diff    /usr/bin/rsnapshot-diff
interval    hourly    6
interval    daily     7
interval    weekly    4
interval    monthly   3
verbose     2
loglevel    4
lockfile    /var/run/rsnapshot.pid
use_lazy_deletes    1
rsync_numtries      2
rsync_short_args        -a
rsync_long_args --delete --numeric-ids --relative --delete-excluded
backup_exec     ssh <user>@<remote-production> "/usr/sbin/peertube postgres:dump /var/peertube/docker-volume/db.tar"
backup  <user>@<remote-production>:/var/peertube  . exclude=docker-volume/db
```

Test this configuration with
```bash
$ rsnapshot configtest
```

#### **Backup**
```bash
$ rsnapshot daily
```

#### **Basic Restore command only for missing files**
```bash
$ rsync -av --delete <mounted-disk-absolute-path>/daily.<day>/var/pertube/  <user>@<remote-production>:/var/pertube/
```

#### **Full Restore command**

```bash
$ rsync -av --delete --ignore-times <mounted-disk-absolute-path>/daily.<day>/var/peertube/  <user>@<remote-production>:/var/pertube/
```

#### **Crontab**
On OPI / RPI:

- Edit crontab with `crontab -u root -e`
- Add this line to run it as docker user every day at 4:25am :

```bash
25 4  * * * /usr/bin/rsnapshot daily
```

## Migration server to server

On the old server :

```bash
$ peertube postgres:dump /var/peertube/docker-volume/db.tar
$ peertube down
$ rsync -av --exclude docker-volume/db /var/peertube/username@new-server:/var/peertube/
```

On the new server :
```bash
$ peertube postgres:up
$ peertube postgres:restore
$ systemctl start peertube
```

## Development

Basic usage with **cURL** or **Wget**.
```shell
GIT_BRANCH=develop sh -c "$(curl -fsSL https://raw.github.com/kimsible/install-peertube/develop/install.sh)"
```
```shell
GIT_BRANCH=develop sh -c "$(wget https://raw.github.com/kimsible/install-peertube/develop/install.sh -O -)"
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
