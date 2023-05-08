"""
'send_receive.py'
=========================================
Sends incrementing values to feeds and subscribes to them

Author(s): Brent Rubell, Todd Treece for Adafruit Industries
"""
# Import standard python modules
import sys
import time

# Import Adafruit IO REST client and MQTTClient
from Adafruit_IO import Client, Feed, MQTTClient

# Set to your Adafruit IO key and username.
ADAFRUIT_IO_KEY = "aio_ZSIg63H2JidvjwjtDWi5qLzcGF8m"
ADAFRUIT_IO_USERNAME = "Edgar21120"

# Set the ID of the feeds to send and subscribe to for updates.
COUNTER1_FEED_ID = "sensor-1"
COUNTER2_FEED_ID = "sensor-2"

# Create an instance of the REST client.
aio = Client(ADAFRUIT_IO_USERNAME, ADAFRUIT_IO_KEY)

# Variables to hold the count for the feeds
sensor1 = 0
sensor2 = 0

# Create an MQTT client instance.
client = MQTTClient(ADAFRUIT_IO_USERNAME, ADAFRUIT_IO_KEY)

#Updating values in Adafruit
def message(client, feed_id, payload):
    global sensor1, sensor2
    
    print("Feed {0} updated its value to: {1}".format(feed_id, payload))
    
    #Uploading the value of sensors
    if feed_id == COUNTER1_FEED_ID:
        sensor1 = int(payload)
        
    elif feed_id == COUNTER2_FEED_ID:
        sensor2 = int(payload)

# Define callback functions for the MQTT client.
def connected(client):

    print("Subscribing to Feed {0}".format(COUNTER1_FEED_ID))
    client.subscribe(COUNTER1_FEED_ID)
    print("Waiting for feed data...")

    print("Subscribing to Feed {0}".format(COUNTER2_FEED_ID))
    client.subscribe(COUNTER2_FEED_ID)
    print("Waiting for feed data...")

#For making the disconnection to Adafruit
def disconnected(client):
    sys.exit(1)

# Setup the callback functions defined above.
client.on_connect = connected
client.on_disconnect = disconnected
client.on_message = message

# Connect to the Adafruit IO server.
client.connect()

# Start the MQTT client's background thread to listen for messages.
client.loop_background()

while True:
    #Adding values to the sensors
    print("Adding 1 to the value of sensor 1: ", sensor1)
    sensor1 += 1
    aio.send_data(COUNTER1_FEED_ID, sensor1)

    print("Adding 1 to the value of sensor 2: ", sensor2)
    sensor2 += 1
    aio.send_data(COUNTER2_FEED_ID, sensor2)

    # Adafruit IO is rate-limited for publishing,
    # so we'll need a delay for calls to aio.send_data()
    time.sleep(3)