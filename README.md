# 👋 wordpress Readme 👋

wordpress README

## Run container

### via command line

```shell
docker run -d \
--restart always \
--name wordpress \
--hostname wordpress \
-e TZ=${TIMEZONE:-America/New_York} \
-v $PWD/wordpress/data:/var/lib/mysql \
-v $PWD/wordpress/config:/usr/html \
-p 80:80 \
casjaysdev/wordpress:latest
```

### via docker-compose

```yaml
version: "2"
services:
  wordpress:
    image: casjaysdev/wordpress
    container_name: wordpress
    environment:
      - TZ=America/New_York
      - HOSTNAME=wordpress
    volumes:
      - $HOME/.local/share/docker/storage/wordpress/data:/var/lib/mysql
      - $HOME/.local/share/docker/storage/wordpress/config:/usr/html
    ports:
      - 80:80
    restart: always
```

## Authors  

🤖 Casjay: [Github](https://github.com/casjay) [Docker](https://hub.docker.com/casjay) 🤖  
⛵ CasjaysDev: [Github](https://github.com/casjaysdev) [Docker](https://hub.docker.com/casjaysdev) ⛵  
