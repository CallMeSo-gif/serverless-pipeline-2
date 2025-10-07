
import boto3
import os
import io 

# Initialize AWS clients
s3_client = boto3.client("s3")
sqs_client = boto3.client("sqs")

# Get the SQS queue URL from environment variable
QUEUE_URL = os.environ.get("QUEUE_URL")


def lambda_handler(event, context):
    """
    Reads CSV files from the bucket and push their S3 path to an SQS queue.
    """
    if not QUEUE_URL:
        raise ValueError("QUEUE_URL environment variable is missing")
    

    for record in event["Records"]:
        bucket = record["s3"]["bucket"]["name"]
        key = record["s3"]["object"]["key"]

        # Only process CSV files
        if key.lower().endswith(".csv"):
            s3_path = f"s3://{bucket}/{key}"
            print(f"Processing file: {s3_path}")

            try:
                # Send S3 path as a message to SQS
                sqs_client.send_message(
                    QueueUrl=QUEUE_URL,
                    MessageBody=s3_path
                )
                print(f"Sent to SQS: {s3_path}")

            except Exception as e:
                print(f"Error sending {s3_path} to SQS: {str(e)}")
        else : 
            print(f"Not a CSV file: {key}")

    return {"status": "Message(s) sent !", "count": len(event["Records"])}
 