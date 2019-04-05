""" MongoDB watcher using change streams. """
import os
import boto3
import pymongo
import logging
from bson.json_util import dumps

LOG = None


def watch_and_push():
    # Setup logging
    global LOG
    LOG = logging.getLogger(__name__)
    handler = logging.StreamHandler()
    formatter = logging.Formatter('%(asctime)s %(levelname)-8s %(message)s')
    handler.setFormatter(formatter)
    LOG.addHandler(handler)
    LOG.setLevel(os.environ.get('LOG_LEVEL', 'INFO'))

    LOG.info('------------------------ STARTING WATCHER ------------------------')

    mongodb_uri = os.environ['MONGODB_URI']
    mongodb_username = os.environ['MONGODB_USERNAME']
    mongodb_password = os.environ['MONGODB_PASSWORD']
    mongodb_database = os.environ['MONGODB_DATABASE']
    mongodb_collection = os.environ['MONGODB_COLLECTION']
    out_kinesis_stream = os.environ['OUT_KINESIS_STREAM']
    kinesis_put_retries = int(os.environ.get('KINESIS_PUT_RETRIES', '3'))

    watcher = Watcher(
        uri=mongodb_uri,
        username=mongodb_username,
        password=mongodb_password,
        db=mongodb_database,
        collection=mongodb_collection
    )

    # Confirm we can talk to MongoDB before starting threads (excepts on auth failure)
    LOG.info(watcher.mongodb_client.server_info())

    # Create publisher
    publisher = Publisher()

    for d_doc in watcher.watch():
        try:
            seq = publisher.publish(d_doc, out_kinesis_stream, kinesis_put_retries)
        except Exception as e:
            LOG.error(e)
            break
        LOG.info('%s = %s', seq, dumps(d_doc))

    watcher.close()
    LOG.info('------------------------ STOPPING WATCHER ------------------------')


class Watcher(object):
    """
    Watcher uses MongoDB change stream to watch for changes in MongoDB collection.
    """

    def __init__(self, uri, username, password, db, collection):
        self._uri = uri
        self._username = username
        self._password = password
        self._db = db
        self._collection = collection
        self._mongodb_client = None

    @property
    def mongodb_client(self):
        if self._mongodb_client is None:
            self._mongodb_client = pymongo.MongoClient(
                self._uri,
                username=self._username,
                password=self._password
            )
        return self._mongodb_client

    @property
    def db(self):
        return self.mongodb_client.get_database(self._db)

    @property
    def collection(self):
        return self.db.get_collection(self._collection)

    @property
    def resume_token(self):
        return None

    def watch(self):
        try:
            with self.collection.watch(full_document='updateLookup', resume_after=self.resume_token) as stream:
                for change in stream:
                    yield change
        except pymongo.errors.PyMongoError:
            # The ChangeStream encountered an unrecoverable error or the
            # resume attempt failed to recreate the cursor.
            LOG.exception('Error while watching collection: ')

    def close(self):
        self.mongodb_client.close()


class Publisher(object):
    """
    Publisher writes raw records to Kinesis stream.
    """

    def __init__(self):
        self.client = boto3.client('kinesis')

    def publish(self, d_record, kinesis_stream, max_retry_count):
        retry_count = max_retry_count
        while retry_count > 0:
            res = None
            try:
                res = self.client.put_record(StreamName=kinesis_stream,
                                             Data=dumps(d_record),
                                             PartitionKey='1')
            except Exception as e:
                LOG.warning('Failed to put record to kinesis stream %s, ERROR: %s', kinesis_stream, e)
            retry_count -= 1
            if res and res['SequenceNumber']:
                return res['SequenceNumber']

        # If control reaches here, put_record() has exhausted all the retries. Raise exception.
        raise Exception('Kinesis put_record failed even after retires')


if __name__ == '__main__':
    watch_and_push()
