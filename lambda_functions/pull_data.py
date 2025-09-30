
import boto3
import os
import awswrangler as wr
import logging
logger = logging.getLogger(__name__)
# New version add logger to replace print statements

 
# Initialize AWS clients
s3_client = boto3.client("s3") #, region_name=region)
sqs_client = boto3.client("sqs") # , region_name=region)

# Get the SQS queue URL from environment variable
QUEUE_URL = os.environ.get("QUEUE_URL")
TARGET_BUCKET = os.environ.get("S3_BUCKET_B")


def lambda_handler(event, Context):
    """
    Function to pull messages from the SQS queue, modify and send to an S3 bucket.
    """

    logger.info(f"TARGET_BUCKET: {TARGET_BUCKET}")
    try:
        response = sqs_client.receive_message(
            QueueUrl=QUEUE_URL,
            MaxNumberOfMessages=5
        )

        messages = response.get('Messages', [])
        logger.info(f"Received {len(messages)} messages from SQS")
        if not messages:
            logger.info("No messages to process.")
            return  # Nothing to process
        

        for message in messages:
            my_path = message["Body"]
            
            key = "/".join(my_path.split("/")[3:])
            df = wr.s3.read_csv(my_path)
            logger.info(f"Read {len(df)} rows from {my_path}")
           
            # 2️ Add a new column
            df["salaire_annuel_eur"] = df["salaire"].str.replace("K", "").astype(int) * 1000 

            # 3️ Write to Parquet in memory
           
            file_name = key.split("/")[-1].replace(".csv", ".parquet")
            output_path = f"s3://{TARGET_BUCKET}/processed/{file_name}"

            logger.info(f"Writing to parquet :  {output_path}")
            wr.s3.to_parquet(
                df=df,
                path=output_path,
                dataset=False,
                index=False
            )
            

            # 4 - Delete the message from the queue after processing
            sqs_client.delete_message(
                QueueUrl=QUEUE_URL,
                ReceiptHandle=message['ReceiptHandle']
            )
            logger.info(f"Deleted message from SQS: {message['MessageId']}")
            

    except Exception as e:
        logger.error(f"Error processing messages: {str(e)}")


