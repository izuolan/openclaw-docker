docker build -t zuolan/openclaw-desktop .

docker run --name build-appimage -dit -v $(pwd)/build:/build zuolan/openclaw-desktop

docker exec -it build-appimage bash

./build-openclaw.sh