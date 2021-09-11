# Tests Guide

Clone the repository

```shell
git clone git@github.com:kimsible/getpeer.tube.git
cd getpeer.tube
```

Test locally install script

```shell
sudo sh script/index.sh
```

Test locally CLI
```shell
sh cli/peertube show-admin
sh cli/peertube show-dkim
sh cli/peertube upgrade
...
```

Clean / uninstall
```shell
sh test/clean.sh
```

Test a specific branch environment

```shell
GIT_BRANCH=develop curl https://raw.githubusercontent.com/kimsible/getpeer.tube/develop/script/index.sh | sh
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

