Deploy asterisk docker with following command,

docker build -t asterisk176 -f Dockerfile .

docker run -d --network=host --name asterisk176 --hostname MiCentralita asterisk176

OR

docker run -d -p 5060:5060 -p 10001-10100:10001-10100/udp --name asterisk176 --hostname MiCentralita asterisk176


Docker expose port range one by one, for UDP 10000-20000 start will take long time, you can add iptable rule like:

iptables -t nat -A  DOCKER -p tcp -m multiport --dports ${PORT_RANGE} -j DNAT --to-destination ${IP}
