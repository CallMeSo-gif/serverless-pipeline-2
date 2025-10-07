import sys
from datetime import datetime
from awsglue.transforms import *
from awsglue.utils import getResolvedOptions
from pyspark.context import SparkContext
from awsglue.context import GlueContext
from awsglue.job import Job
from pyspark.sql.functions import current_timestamp, lit
import logging

# Configuration du logger
logger = logging.getLogger()
logger.setLevel(logging.INFO)

# Initialisation du contexte Glue
sc = SparkContext()
glueContext = GlueContext(sc)
spark = glueContext.spark_session
job = Job(glueContext)

logger.info("Starting ETL job")

# Récupération des paramètres
args = getResolvedOptions(
    sys.argv, 
    ["JOB_NAME", "DATABASE_NAME", "TABLE_NAME", "OUTPUT_BUCKET", "OUTPUT_PREFIX"]
)

DATABASE_NAME = args["DATABASE_NAME"]
TABLE_NAME = args["TABLE_NAME"]
OUTPUT_BUCKET = args["OUTPUT_BUCKET"]
OUTPUT_PREFIX = args["OUTPUT_PREFIX"]

job.init(args["JOB_NAME"], args)

logger.info(f"Retrieving data from table {TABLE_NAME} in database {DATABASE_NAME}")

# Lecture des données depuis le Glue Catalog
datasource = glueContext.create_dynamic_frame.from_catalog(
    database=DATABASE_NAME,
    table_name=TABLE_NAME,
    transformation_ctx="datasource"
)

logger.info("Convert DynamicFrame to Spark DataFrame")

# Conversion en DataFrame Spark
df = datasource.toDF()

# Ajout de la colonne processed_at
df = df.withColumn("processed_at", current_timestamp())
logger.info("Added processed_at column with current timestamp")

# Écriture en Parquet sur S3
output_path = f"s3://{OUTPUT_BUCKET}/{OUTPUT_PREFIX}"

df.write \
    .mode("overwrite") \
    .parquet(output_path)

logger.info(f"Data written to {output_path}")

# Commit du job
job.commit()

logger.info("ETL job completed successfully")