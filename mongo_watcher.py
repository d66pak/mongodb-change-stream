""" MongoDB watcher using change streams. """
import os
import ast
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
    l_out_kinesis_streams = set(ast.literal_eval(os.environ.get('OUT_KINESIS_STREAMS', '[]')))

    watcher = Watcher(
        uri=mongodb_uri,
        username=mongodb_username,
        password=mongodb_password,
        db=mongodb_database,
        collection=mongodb_collection
    )

    # Confirm we can talk to MongoDB before starting threads (excepts on auth failure)
    LOG.info(watcher.mongodb_client.server_info())

    for d_doc in watcher.watch():
        LOG.info(dumps(d_doc))

    watcher.close()
    LOG.info('---------')


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


if __name__ == '__main__':
    watch_and_push()
