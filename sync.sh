jsonnet -m output -S main.jsonnet

RPI01=10.10.101.0
RPI02=10.10.102.0

rsync -aP output/rpi01/ ubuntu@$RPI01:/home/ubuntu
ssh ubuntu@$RPI01 docker-compose up -d 
ssh ubuntu@$RPI01 docker exec pihole pihole restartdns

rsync -aP output/rpi02/ ubuntu@$RPI02:/home/ubuntu
ssh ubuntu@$RPI02 docker-compose up -d