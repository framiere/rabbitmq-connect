# Do all in one

```
$ ./run.sh
...
+ docker-compose exec connect curl localhost:8083/connector-plugins
+ jq '.[] | select(.class=="io.confluent.connect.rabbitmq.RabbitMQSourceConnector")'
{
  "class": "io.confluent.connect.rabbitmq.RabbitMQSourceConnector",
  "type": "source",
  "version": "0.0.0.0"
}
+ docker-compose exec rabbit-client /scripts/send.py
 [x] Sent 'Hello World!'
+ docker-compose exec rabbitmq rabbitmqadmin get queue=sample count=100
+-------------+----------+---------------+--------------+---------------+------------------+------------+-------------+
| routing_key | exchange | message_count |   payload    | payload_bytes | payload_encoding | properties | redelivered |
+-------------+----------+---------------+--------------+---------------+------------------+------------+-------------+
| sample      |          | 0             | Hello World! | 12            | string           |            | False       |
+-------------+----------+---------------+--------------+---------------+------------------+------------+-------------+
+ docker-compose exec rabbitmq rabbitmqadmin publish routing_key=sample 'payload=from command line'
Message published
+ docker-compose exec rabbitmq rabbitmqadmin get queue=sample count=100
+-------------+----------+---------------+-------------------+---------------+------------------+------------+-------------+
| routing_key | exchange | message_count |      payload      | payload_bytes | payload_encoding | properties | redelivered |
+-------------+----------+---------------+-------------------+---------------+------------------+------------+-------------+
| sample      |          | 1             | Hello World!      | 12            | string           |            | True        |
| sample      |          | 0             | from command line | 17            | string           |            | False       |
+-------------+----------+---------------+-------------------+---------------+------------------+------------+-------------+
+ HEADER='Content-Type: application/json'
++ cat
+ DATA='{
  "name" : "rabbit-connector",
  "config" : {
    "connector.class" : "io.confluent.connect.rabbitmq.RabbitMQSourceConnector",
    "value.converter": "org.apache.kafka.connect.converters.ByteArrayConverter",
    "tasks.max" : "1",
    "kafka.topic" : "sample",
    "rabbitmq.host" : "rabbitmq",
    "rabbitmq.queue" : "sample"
  }
}'
+ docker-compose exec connect curl -s -X POST -H 'Content-Type: application/json' --data '{
  "name" : "rabbit-connector",
  "config" : {
    "connector.class" : "io.confluent.connect.rabbitmq.RabbitMQSourceConnector",
    "value.converter": "org.apache.kafka.connect.converters.ByteArrayConverter",
    "tasks.max" : "1",
    "kafka.topic" : "sample",
    "rabbitmq.host" : "rabbitmq",
    "rabbitmq.queue" : "sample"
  }
}' http://localhost:8083/connectors
+ jq .
{
  "name": "rabbit-connector",
  "config": {
    "connector.class": "io.confluent.connect.rabbitmq.RabbitMQSourceConnector",
    "value.converter": "org.apache.kafka.connect.converters.ByteArrayConverter",
    "tasks.max": "1",
    "kafka.topic": "sample",
    "rabbitmq.host": "rabbitmq",
    "rabbitmq.queue": "sample",
    "name": "rabbit-connector"
  },
  "tasks": [],
  "type": "source"
}
+ docker-compose exec rabbitmq rabbitmqadmin publish routing_key=sample 'payload={"msg": "hello world"}' 'properties={"delivery_mode":2, "priority": 1, "content_type":"application/json"}' payload_encoding=string
Message published
+ docker-compose exec kafka-1 kafka-console-consumer --bootstrap-server localhost:9092 --topic sample --from-beginning --max-messages=1
{"msg":"hello"}
Processed a total of 1 messages
```

# Setup Rabbit

```
$ docker-compose exec rabbit-client /scripts/send.py
 [x] Sent 'Hello World!'
 
$ docker-compose exec rabbit-client /scripts/receive.py
 [*] Waiting for messages. To exit press CTRL+C
 [x] Received b'Hello World!'
 

$ docker-compose exec rabbitmq rabbitmqadmin get queue=sample count=100
+-------------+----------+---------------+--------------+---------------+------------------+------------+-------------+
| routing_key | exchange | message_count |   payload    | payload_bytes | payload_encoding | properties | redelivered |
+-------------+----------+---------------+--------------+---------------+------------------+------------+-------------+
| sample      |          | 0             | Hello World! | 12            | string           |            | True        |
+-------------+----------+---------------+--------------+---------------+------------------+------------+-------------+

$ docker-compose exec rabbitmq rabbitmqadmin publish routing_key=sample payload='from command line'
Message published

$ docker-compose exec rabbitmq rabbitmqadmin get queue=sample count=100
+-------------+----------+---------------+-------------------+---------------+------------------+------------+-------------+
| routing_key | exchange | message_count |      payload      | payload_bytes | payload_encoding | properties | redelivered |
+-------------+----------+---------------+-------------------+---------------+------------------+------------+-------------+
| sample      |          | 1             | Hello World!      | 12            | string           |            | True        |
| sample      |          | 0             | from command line | 17            | string           |            | False       |
+-------------+----------+---------------+-------------------+---------------+------------------+------------+-------------+

$ docker-compose exec rabbitmq rabbitmqadmin publish routing_key=sample payload='{"msg":"hello"}'


```


# Setup connector
```

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
{
  "name": "rabbit-connector",
  "config": {
    "connector.class": "io.confluent.connect.rabbitmq.RabbitMQSourceConnector",
    "value.converter": "org.apache.kafka.connect.converters.ByteArrayConverter",
    "tasks.max": "1",
    "kafka.topic": "sample",
    "rabbitmq.host": "rabbitmq",
    "rabbitmq.queue": "sample",
    "name": "rabbit-connector"
  },
  "tasks": [
    {
      "connector": "rabbit-connector",
      "task": 0
    }
  ],
  "type": "source"
}

docker-compose exec connect curl -s -X GET -H "${HEADER}" http://localhost:8083/connectors/rabbit-connector/status | jq .
docker-compose exec connect curl -s -X DELETE -H "${HEADER}" http://localhost:8083/connectors/rabbit-connector

```

## Why is connect starting faster than on my machine ?

I request to load only a single connector here
```
CONNECT_PLUGIN_PATH: "/usr/share/confluent-hub-components"
``` 

# Verify on kafka 

```
docker-compose exec kafka-1 kafka-topics --zookeeper zookeeper:2181 --list


docker-compose exec kafka-1 kafka-console-consumer --bootstrap-server localhost:9092 --topic sample --from-beginning --max-messages=1
{"msg":"hello"}
Processed a total of 1 messages
```
