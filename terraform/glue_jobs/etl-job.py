import boto3
import csv
import os
from datetime import datetime
from awsglue.utils import getResolvedOptions
import logging
import sys
import pandas as pd
from io import BytesIO


logger = logging.getLogger(__name__)
logger.setLevel(logging.INFO)

logger.info("Starting ETL job") 
# Environment variables or job arguments passed from Glue
args = getResolvedOptions(sys.argv, ["DATABASE_NAME", "TABLE_NAME", "OUTPUT_BUCKET", "OUTPUT_PREFIX"])
DATABASE_NAME = args["DATABASE_NAME"]
TABLE_NAME    = args["TABLE_NAME"]
OUTPUT_BUCKET = args["OUTPUT_BUCKET"]
OUTPUT_PREFIX = args["OUTPUT_PREFIX"]
logger.info('Retrieving data from table %s in database %s', TABLE_NAME, DATABASE_NAME)


# Boto3 clients
glue = boto3.client("glue")
s3   = boto3.client("s3")

# -----------------------------------------------------------------------------
# 1. Get table metadata from the Glue Data Catalog
# -----------------------------------------------------------------------------
response = glue.get_table(DatabaseName=DATABASE_NAME, Name=TABLE_NAME)
table_metadata = response["Table"]

input_s3_path = table_metadata["StorageDescriptor"]["Location"]
logger.info('Input S3 path: %s', input_s3_path)


# -----------------------------------------------------------------------------
# 2. Read processed data from S3
# -----------------------------------------------------------------------------
bucket_name = input_s3_path.replace("s3://", "").split("/")[0]
prefix = "/".join(input_s3_path.replace("s3://", "").split("/")[1:])


objects = s3.list_objects_v2(Bucket=bucket_name, Prefix=prefix)
if len(objects.get("Contents", [])) == 0:
    raise Exception("No input files found in S3!")

for obj in objects["Contents"]:
    logger.info("Reading input file: %s", obj["Key"])
    obje = s3.get_object(Bucket=bucket_name, Key=obj["Key"])
    logger.info("Reading input file: %s", obj["Key"])
    data = obje["Body"].read()
    logger.info("Loading the body : ", data)
    

    df = pd.read_parquet(BytesIO(data))
    logger.info(f"Processing file: {obj['Key']}")

    df["processed_at"] = pd.Timestamp.now()
    #df.to_parquet("data/output.parquet", index=False)
    logger.info("Transformed data and added 'processed_at' column", df)
    parts = obj['Key'].split('/')          
    file_name = parts[-1] 
    output_key = f"{OUTPUT_PREFIX}{file_name}"
    logger.info("Transforming output key file %s:" , output_key)
    
    buffer = BytesIO()
    df.to_parquet(buffer, index=False)
    
    # Reset buffer cursor
    buffer.seek(0)
    s3.put_object(
        Bucket=OUTPUT_BUCKET,
        Key=output_key,
        Body=buffer.getvalue()
    )
    logger.info(f"Wrote into output bucket: {OUTPUT_BUCKET}{output_key}")

