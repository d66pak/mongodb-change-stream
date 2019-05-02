""" MongoDB watcher using change streams. """
import decimal
import json
import logging
import os

import boto3
import pymongo
from bson.json_util import dumps
from bson.objectid import ObjectId
from pymongo import MongoClient
from pymongo.collection import Collection
from pymongo.database import Database
from typing import AnyStr, Optional, Dict, Generator

LOG = None


def watch_and_push() -> None:
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
    dynamodb_table_name = os.environ.get('DYNAMODB_TABLE_NAME', None)

    watcher = Watcher(
        uri=mongodb_uri,
        username=mongodb_username,
        password=mongodb_password,
        db=mongodb_database,
        collection=mongodb_collection,
        dynamodb_table_name=dynamodb_table_name
    )

    # Confirm we can talk to MongoDB before starting threads (excepts on auth failure)
    LOG.info(watcher.mongodb_client.server_info())

    # Create publisher
    publisher = Publisher(mongodb_collection)

    for d_doc in watcher.watch():
        try:
            publisher.publish(d_doc, out_kinesis_stream, kinesis_put_retries)
        except:
            LOG.exception('Failed to publish record: ')
            break
        # ------ Mark the doc successful at the end ------ #
        watcher.mark(d_doc)

    watcher.close()
    LOG.info('------------------------ STOPPING WATCHER ------------------------')


class Watcher(object):
    """
    Watcher uses MongoDB change stream to watch for changes in MongoDB collection.
    """

    def __init__(self, uri: AnyStr, username: AnyStr, password: AnyStr,
                 db: AnyStr, collection: AnyStr, dynamodb_table_name: Optional[AnyStr] = None) -> None:
        self._uri = uri
        self._username = username
        self._password = password
        self._db = db
        self._collection = collection
        self._mongodb_client = None
        self._ddb = None
        self._dynamodb_table_name = dynamodb_table_name
        if dynamodb_table_name:
            self._ddb = boto3.resource('dynamodb', region_name=os.environ['AWS_DEFAULT_REGION'])
        else:
            self._ddb = None

    @property
    def mongodb_client(self) -> MongoClient:
        if self._mongodb_client is None:
            self._mongodb_client = pymongo.MongoClient(
                self._uri,
                username=self._username,
                password=self._password
            )
        return self._mongodb_client

    @property
    def db(self) -> Database:
        return self.mongodb_client.get_database(self._db)

    @property
    def collection(self) -> Collection:
        return self.db.get_collection(self._collection)

    @property
    def resume_token(self) -> Optional[AnyStr]:
        if self._ddb:
            d_key = {'collectionName': '{db}.{c}'.format(db=self._db, c=self._collection)}
            d_res = self._ddb.Table(self._dynamodb_table_name).get_item(Key=d_key)
            if 'Item' in d_res:
                d_item = json.loads(json.dumps(d_res['Item'], cls=DecimalEncoder))
                LOG.debug("get_item for key: %s in table '%s' returned attributes : %s", d_key, self._dynamodb_table_name, d_item)
                return d_item['_id']
        return None

    def watch(self) -> Generator[Dict, None, None]:
        try:
            with self.collection.watch(full_document='updateLookup', resume_after=self.resume_token) as stream:
                for change in stream:
                    yield change
        except pymongo.errors.PyMongoError:
            # The ChangeStream encountered an unrecoverable error or the
            # resume attempt failed to recreate the cursor.
            LOG.exception('Error while watching collection: ')

    def mark(self, d_doc: Dict) -> None:
        if self._ddb:
            d_key = {'collectionName': '{db}.{c}'.format(db=self._db, c=self._collection)}
            d_res = self._ddb.Table(self._dynamodb_table_name).update_item(
                Key=d_key,
                UpdateExpression='SET #id=:id',
                ExpressionAttributeValues={':id': d_doc['_id']},
                ExpressionAttributeNames={'#id': '_id'},  # Required to create a key name starting with underscore
                ReturnValues='UPDATED_NEW'
            )
            LOG.debug("update_item for key: %s in table '%s' successfully updated attributes: %s",
                      d_key, self._dynamodb_table_name, d_res['Attributes'])

    def close(self) -> None:
        self.mongodb_client.close()


class Publisher(object):
    """
    Publisher writes raw records to Kinesis stream.
    """

    def __init__(self, collection: AnyStr) -> None:
        self.client = boto3.client('kinesis')
        self._coll = collection

    def publish(self, d_record: Dict, kinesis_stream: AnyStr, max_retry_count: int) -> None:
        retry_count = max_retry_count
        while retry_count > 0:
            res = None
            str_record = dumps(d_record)
            try:
                res = self.client.put_record(StreamName=kinesis_stream,
                                             Data=str_record,
                                             PartitionKey='1')
            except Exception as e:
                LOG.warning('Failed to put record to kinesis stream %s, ERROR: %s', kinesis_stream, e)
            retry_count -= 1
            if res and res['SequenceNumber']:
                LOG.info('(Processed) coll:%s id:%s seq:%s',
                         self._coll, self._objectid_to_str(d_record['documentKey']['_id']), res['SequenceNumber'])
                LOG.debug('%s', str_record)
                return res['SequenceNumber']

        # If control reaches here, put_record() has exhausted all the retries. Raise exception.
        raise Exception('Kinesis put_record failed even after retires')

    @staticmethod
    def _objectid_to_str(oid) -> AnyStr:
        return str(oid) if isinstance(oid, ObjectId) else oid


# Helper class to convert a DynamoDB item to JSON.
class DecimalEncoder(json.JSONEncoder):
    def default(self, o):
        if isinstance(o, decimal.Decimal):
            if o % 1 > 0:
                return float(o)
            else:
                return int(o)
        return super(DecimalEncoder, self).default(o)


if __name__ == '__main__':
    watch_and_push()
