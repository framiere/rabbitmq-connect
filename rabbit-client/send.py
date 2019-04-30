#!/usr/bin/env python
import pika

connection = pika.BlockingConnection(pika.ConnectionParameters('rabbitmq'))
channel = connection.channel()
channel.basic_publish(exchange='',
                      routing_key='sample',
                      body='Hello World!',
                      properties=pika.BasicProperties(
                         content_type='text/plain',
                         delivery_mode = 2, # make message persistent
                         priority = 1,
                         )
                      )
print(" [x] Sent 'Hello World!'")
connection.close()
