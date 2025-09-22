
import boto3
import os
import pandas as pd
import io 
import json
import awswrangler as wr
#region = os.environ.get("AWS_REGION", "eu-west-3")
 
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
    if not QUEUE_URL:
        raise ValueError("QUEUE_URL environment variable is missing")

    print(f"Target bucket: {TARGET_BUCKET}")
    try:
        response = sqs_client.receive_message(
            QueueUrl=QUEUE_URL,
            MaxNumberOfMessages=10,
            WaitTimeSeconds=5
        )

        messages = response.get('Messages', [])
        if not messages:
            print("No messages in SQS, exiting.")
            return  # Nothing to process
        

        for message in messages:

            my_path = message["Body"]
        
            bucket = my_path.split("/")[2]
            key = "/".join(my_path.split("/")[3:])

         

            # 1️ Read the CSV file from S3 into a DataFrame
            obj = s3_client.get_object(Bucket=bucket, Key=key) # returns a dict
            body = obj["Body"].read() # read all data in the file -> it gives bytes

            
            df = pd.read_csv(io.BytesIO(body)) # read the csv file in a dataframe

           
            # 2️ Add a new column
            df["salaire_annuel_eur"] = df["salaire"].str.replace("K", "").astype(int) * 1000 

            # 3️ Write to Parquet in memory
           
            file_name = key.split("/")[-1].replace(".csv", ".parquet")
            output_path = f"s3://{TARGET_BUCKET}/processed/{file_name}"
        
            wr.s3.to_parquet(
                df=df,
                path=output_path,
                dataset=False,  # write a single file
                index=False
            )
            

            # 4 - Delete the message from the queue after processing
            sqs_client.delete_message(
                QueueUrl=QUEUE_URL,
                ReceiptHandle=message['ReceiptHandle']
            )
            print(f"Deleted message: {message['MessageId']}")
            

        if not messages:
            print("No messages in the queue.")

    except Exception as e:
        print(f"Error : {str(e)}")


