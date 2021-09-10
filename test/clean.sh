#!/usr/bin/env sh

# remove systemd service
if [ -d /etc/systemd/system/peertube.service ]; then
  sudo systemctl disable peertube # disabled peertube service
  sudo rm -f /etc/systemd/system/peertube.service # delete peertube service
fi

# clean stack
if [ -d /var/peertube ]; then
  cd /var/peertube
  docker-compose down -v --remove-orphans # down all containers
  sudo rm -rf /var/peertube #remove peertube stack
fi

# clean docker cached images and volumes
[ ! -z "$(docker images -a -q)" ] && docker rmi $(docker images -a -q) # remove all cached images
[ ! -z "$(docker volume ls -q)" ] && docker volume rm $(docker volume ls -q) # remove all cached volumes

# clean docker network
docker network prune -f # remove all unsued networks

# remove cli
sudo rm -f /usr/sbin/peertube # remove CLI

