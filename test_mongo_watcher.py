import os
import mongo_watcher

# Setup required environment variables for mongo watcher
os.environ['LOG_LEVEL'] = 'DEBUG'
os.environ['AWS_DEFAULT_REGION'] = 'ap-southeast-2'
os.environ['MONGODB_URI'] = 'mongodb://replica-1:27017,replica-2:27017,replica-3:27017/test?ssl=true&replicaSet=test-shard-0&authSource=admin&retryWrites=true'
os.environ['MONGODB_URI'] = 'mongodb+srv://<dns-server-url>/<db>?authSource=<auth_db>'
os.environ['MONGODB_USERNAME'] = '<username>'
os.environ['MONGODB_PASSWORD'] = '<password>'
os.environ['MONGODB_DATABASE'] = '<database>'
os.environ['MONGODB_COLLECTION'] = '<collection>'

mongo_watcher.watch_and_push()
