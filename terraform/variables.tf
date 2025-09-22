variable "region" {
  description = "The AWS region to deploy resources in"
  type        = string
  default     = "eu-west-1"
  
}

variable "bucketA" {
  description = "The name of the S3 bucket to trigger the lambda function"
  type        = string
  default = "bucket-a-csv-565"
}

variable "bucketB" {
  description = "The name of the second S3 bucket to store the parquet file"
  type        = string
  default = "bucket-b-parquet-565"
  
}

variable "lambdaA" {
  description = "The name of the Lambda function to process file in the bucketA"
  type        = string
  default = "pushDataFunction"
}


variable "lambdaB" {
  description = "The name of the second Lambda function to convert CSV file to Parquet"
  type        = string
  default = "pullDataFunction" 
  
  
}

variable "sqs_queue" {
  description = "The name of the SQS queue to store messages from the lambdaA function"
  type        = string
  default = "my-sqs-queue"
  
}

variable "lambda2_schedule_expression" {
  default = "rate(10 minutes)"
}