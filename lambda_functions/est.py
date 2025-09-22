import pull_data as lambda2

# Simulated SQS message (plain string body)
event = {
    "Records": [
        {
            "messageId": "1",
            "receiptHandle": "abc",
            "body": "s3://bucket-a-csv-565/to_process/fichier.csv",
            "attributes": {},
            "messageAttributes": {},
            "md5OfBody": "xyz",
            "eventSource": "aws:sqs",
            "eventSourceARN": "arn:aws:sqs:eu-west-1:123456789012:your-queue",
            "awsRegion": "eu-west-3"
        }
    ]
}

# Call handler directly
lambda2.lambda_handler(event, None)