
import boto3
import pandas as pd
import awswrangler as wr
import os
from awsglue.utils import getResolvedOptions
import sys
import logging

logger = logging.getLogger()
logging.basicConfig(level=logging.INFO)

glueclient = boto3.client('glue')

logger.info("Starting ETL job") 

args = getResolvedOptions(sys.argv, ["DATABASE_NAME", "TABLE_NAME", "OUTPUT_BUCKET", "OUTPUT_PREFIX", "AWS_DEFAULT_REGION"])
DATABASE_NAME = args["DATABASE_NAME"]
TABLE_NAME    = args["TABLE_NAME"]
OUTPUT_BUCKET = args["OUTPUT_BUCKET"]
OUTPUT_PREFIX = args["OUTPUT_PREFIX"]
AWS_DEFAULT_REGION = args["AWS_DEFAULT_REGION"]
logger.info('Retrieving data from table %s in database %s', TABLE_NAME, DATABASE_NAME)

#table = glueclient.get_table(DatabaseName = DATABASE_NAME, Name = TABLE_NAME)

query = f"SELECT * FROM {DATABASE_NAME}.{TABLE_NAME}"
logger.info(f"Athena Query: {query}")

# Read the data from Athena
df = wr.athena.read_sql_query(
    query, 
    database=DATABASE_NAME
logger.info(f"Convert the Athena query into a DataFrame")

df["processed_at"] = pd.Timestamp.now()
logger.info("Added processed_at column with current timestamp")

# Write the dataframe into a new S3 bucket
re = wr.s3.to_parquet (
    df=df,
    path= f"s3://{OUTPUT_BUCKET}/{OUTPUT_PREFIX}",
    dataset=True,
    mode='overwrite',
    #database=DATABASE_NAME, 
    #table=TABLE_NAME  
)
logger.info(f"Data written to s3://{OUTPUT_BUCKET}/{OUTPUT_PREFIX} and registered in Glue Data Catalog")




