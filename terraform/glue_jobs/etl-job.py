import boto3
import csv
import io
import os
from datetime import datetime

# Environment variables or job arguments passed from Glue
DATABASE_NAME = os.environ.get("DATABASE_NAME", "my_database")
TABLE_NAME    = os.environ.get("TABLE_NAME", "my_table")
OUTPUT_BUCKET = os.environ.get("OUTPUT_BUCKET", "my-output-bucket")
OUTPUT_PREFIX = os.environ.get("OUTPUT_PREFIX", "results/")

# Boto3 clients
glue = boto3.client("glue")
s3   = boto3.client("s3")

# -----------------------------------------------------------------------------
# 1. Get table metadata from the Glue Data Catalog
# -----------------------------------------------------------------------------
response = glue.get_table(DatabaseName=DATABASE_NAME, Name=TABLE_NAME)
table_metadata = response["Table"]

# For simplicity: assume the table points to a single S3 location
input_s3_path = table_metadata["StorageDescriptor"]["Location"]
print(f"Input data location: {input_s3_path}")

# -----------------------------------------------------------------------------
# 2. Read raw data from S3 (assuming CSV in this example)
# -----------------------------------------------------------------------------
bucket_name = input_s3_path.replace("s3://", "").split("/")[0]
prefix = "/".join(input_s3_path.replace("s3://", "").split("/")[1:])

# Get first object (simplification: production jobs may loop over all objects)
objects = s3.list_objects_v2(Bucket=bucket_name, Prefix=prefix)
if "Contents" not in objects:
    raise Exception("No input files found in S3!")

first_key = objects["Contents"][0]["Key"]
obj = s3.get_object(Bucket=bucket_name, Key=first_key)
data = obj["Body"].read().decode("utf-8")

# Load CSV into memory
rows = list(csv.DictReader(io.StringIO(data)))

# -----------------------------------------------------------------------------
# 3. Add new column
# -----------------------------------------------------------------------------
for row in rows:
    row["processed_at"] = datetime.utcnow().isoformat()

# -----------------------------------------------------------------------------
# 4. Write back to S3 as new CSV
# -----------------------------------------------------------------------------
output_csv = io.StringIO()
writer = csv.DictWriter(output_csv, fieldnames=rows[0].keys())
writer.writeheader()
writer.writerows(rows)

output_key = f"{OUTPUT_PREFIX}transformed_{datetime.utcnow().strftime('%Y%m%d%H%M%S')}.csv"
s3.put_object(
    Bucket=OUTPUT_BUCKET,
    Key=output_key,
    Body=output_csv.getvalue().encode("utf-8")
)

print(f"✅ Wrote transformed file to s3://{OUTPUT_BUCKET}/{output_key}")