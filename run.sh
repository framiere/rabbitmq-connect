#!/bin/bash -x

docker-compose down -v
docker-compose up -d > /dev/null

while [[ ! $(docker-compose logs connect) =~ "Herder started" ]]; do
  sleep 3
done

docker-compose exec connect curl localhost:8083/connector-plugins | jq '.[] | select(.class=="io.confluent.connect.rabbitmq.RabbitMQSourceConnector")'
docker-compose exec rabbit-client /scripts/send.py
docker-compose exec rabbitmq rabbitmqadmin get queue=sample count=100
docker-compose exec rabbitmq rabbitmqadmin publish routing_key=sample payload='from command line'
docker-compose exec rabbitmq rabbitmqadmin get queue=sample count=100
HEADER="Content-Type: application/json"
DATA=$( cat << EOF
{
  "name" : "rabbit-connector",
  "config" : {
    "connector.class" : "io.confluent.connect.rabbitmq.RabbitMQSourceConnector",
    "value.converter": "org.apache.kafka.connect.converters.ByteArrayConverter",
    "tasks.max" : "1",
    "kafka.topic" : "sample",
    "rabbitmq.host" : "rabbitmq",
    "rabbitmq.queue" : "sample"
  }
}
EOF
)

docker-compose exec connect curl -s -X POST -H "${HEADER}" --data "${DATA}" http://localhost:8083/connectors | jq .

docker-compose exec rabbitmq rabbitmqadmin publish routing_key=sample payload='{"msg": "hello world"}' properties='{"delivery_mode":2, "priority": 1, "content_type":"application/json"}' payload_encoding='string'

docker-compose exec kafka-1 kafka-console-consumer --bootstrap-server localhost:9092 --topic sample --from-beginning
