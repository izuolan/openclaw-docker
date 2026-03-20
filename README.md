docker build -t zuolan/openclaw-desktop .

docker run --name build-appimage -dit -v "$(pwd)/build:/build" zuolan/openclaw-desktop

docker exec -it build-appimage bash

./build-openclaw.sh

docker rm -f build-appimage

docker-compose up -d


docker exec -it openclaw-desktop bash