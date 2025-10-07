##===================================================================
## LAMBDA FUNCTION TO PUSH THE DATA TO THE SAS QUEUE
##===================================================================

#### 1 - Create the IAM role for the Lambda function with necessary permissions
# Creating a role for the lambda function 

resource "aws_iam_role" "lambda_exec" {
  name = "lambda_role"

  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Action = "sts:AssumeRole"
        Effect = "Allow"
        Principal = {
          Service = "lambda.amazonaws.com"
        }
      },
    ]
  })
}

# 2 - Create the plocies : 
# Allow the lambda function  to read from the S3 bucket
resource "aws_iam_policy" "lambda_policy" {
  name        = "lambda-policy"
  description = "Allow Lambda to read from S3 bucket"
  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Action   = "s3:GetObject",
        Effect   = "Allow",
        Resource = "${aws_s3_bucket.tf_bucket.arn}/to_process/*",
      },
      {
        Effect = "Allow"
        Action = [
          "s3:PutObject"
        ]
        Resource =   "${aws_s3_bucket.tf_bucket_2.arn}/*"
      },
      {
        Action   = [
          "s3:ListBucket",
        ],
        Effect   = "Allow",
        Resource = [ "${aws_s3_bucket.tf_bucket.arn}", "${aws_s3_bucket.tf_bucket_2.arn}"]
      },
      {
        Action   = ["logs:CreateLogGroup", "logs:CreateLogStream", "logs:PutLogEvents"],
        Effect   = "Allow",
        Resource = "*"
      },
       {
        Action = [
          "sqs:SendMessage",
          "sqs:ReceiveMessage",
          "sqs:DeleteMessage",
          "sqs:GetQueueAttributes"
        ]
        Effect = "Allow"
        Resource = "${aws_sqs_queue.terraform_queue.arn}"
      }
    ]
  })
}


# 3 - Allow S3 to trigger the Lambda function when a new object is created in the bucket
resource "aws_lambda_permission" "allow_s3" {
  statement_id  = "AllowS3Invoke"
  action        = "lambda:InvokeFunction"
  function_name = module.lambda_function.lambda_function_name
  principal     = "s3.amazonaws.com"
  source_arn    = aws_s3_bucket.tf_bucket.arn
}

resource "aws_s3_bucket_notification" "bucket_notification" {
  bucket = aws_s3_bucket.tf_bucket.id

  lambda_function {
    lambda_function_arn = module.lambda_function.lambda_function_arn
    events              = ["s3:ObjectCreated:*"]  
    filter_prefix       = "to_process/"          
  }

  depends_on = [aws_lambda_permission.allow_s3]
}




# Attach policies to the role created above (send logs to cloudwatch and GetObject from the S3 bucket)
resource "aws_iam_role_policy_attachment" "attach_policy" {
  role       = aws_iam_role.lambda_exec.name
  policy_arn = aws_iam_policy.lambda_policy.arn
}

resource "aws_iam_role_policy_attachment" "attach_policy_cloudwatch" {
  role       = aws_iam_role.lambda_exec.name
  policy_arn = "arn:aws:iam::aws:policy/service-role/AWSLambdaBasicExecutionRole"
}

/*

# Archive a single file.
data "archive_file" "zip_lambda" {
  type        = "zip"
  source_file = "${path.module}/../lambda_functions/push_data.py"
  output_path = "${path.module}/pushDataFunction.zip"
}

*/

module "lambda_function" {
  source  = "terraform-aws-modules/lambda/aws"
  version = "~> 6.0"

  function_name = var.lambdaA
  description   = "Sends S3 file info to SQS"
  handler       = "push_data.lambda_handler"
  runtime       = "python3.13"
  timeout       = 300
  memory_size   = 1024

  source_path = "${path.module}/../lambda_functions/push_data"  # Folder containing your main.py

  environment_variables = {
    QUEUE_URL   = aws_sqs_queue.terraform_queue.id
  }

  attach_policy_json = false
  # On utilise le rôle existant
  lambda_role = aws_iam_role.lambda_exec.arn
}


/*
# Create the Lambda function
resource "aws_lambda_function" "process_s3_files" {
 
  function_name = var.lambdaA
  role          = aws_iam_role.lambda_exec.arn
  handler       = "push_data.lambda_handler"
  runtime       = "python3.13"
  filename      = data.archive_file.zip_lambda.output_path 

  # Redeploy the lambda if the index.py file changes
  source_code_hash = data.archive_file.zip_lambda.output_base64sha256


  environment {
    variables = {
      QUEUE_URL   = aws_sqs_queue.terraform_queue.id
    }
  }
  
  tags = {
    tag-key = "push_data_to_sqs"
  }
}



# Archive a single file.
data "archive_file" "zip_lambda2" {
  type        = "zip"
  source_file = "${path.module}/../lambda_functions/pull_data.py"
  output_path = "${path.module}/pullDataFunction.zip"
}




resource "aws_lambda_function" "csv_to_parquet" {
  function_name = var.lambdaB
  role          = aws_iam_role.lambda_exec.arn
  handler       = "pull_data.lambda_handler"
  runtime       = "python3.13"
  filename      = data.archive_file.zip_lambda2.output_path 
  memory_size = 250
  timeout = 10

  # Redeploy the lambda if the .py file changes
  source_code_hash = data.archive_file.zip_lambda2.output_base64sha256


  environment {
    variables = {
      QUEUE_URL   = aws_sqs_queue.terraform_queue.id
      S3_BUCKET_B = aws_s3_bucket.tf_bucket_2.bucket
    }
  }

  layers = [
            "arn:aws:lambda:eu-west-3:183295454956:layer:aws-data-wrangler:2"
          ] 


}
*/
module "lambda_function_2" {
  source  = "terraform-aws-modules/lambda/aws"
  version = "~> 6.0"

  function_name = var.lambdaB
  description   = "Reads from SQS, converts CSV to Parquet, and uploads to S3"
  handler       = "pull_data.lambda_handler"
  runtime       = "python3.13"
  timeout       = 300
  memory_size   = 1024

  source_path = "${path.module}/../lambda_functions/pull_data"  # Folder containing your main.py

  environment_variables = {
    QUEUE_URL   = aws_sqs_queue.terraform_queue.id
    S3_BUCKET_B = aws_s3_bucket.tf_bucket_2.bucket
  }

  layers = [ "arn:aws:lambda:eu-west-3:183295454956:layer:aws-data-wrangler:2"    ] 

  attach_policy_json = false
  # On utilise le rôle existant
  lambda_role = aws_iam_role.lambda_exec.arn
}
  
# Scheduled Lambda 2
resource "aws_cloudwatch_event_rule" "every_10m" {
  name                = "lambda2_schedule_rule"
  schedule_expression = "cron(0/5 * * * ? *)"
}

resource "aws_cloudwatch_event_target" "invoke_lambda2" {
  rule = aws_cloudwatch_event_rule.every_10m.name
  arn  = module.lambda_function_2.lambda_function_arn
}

resource "aws_lambda_permission" "allow_events_invoke" {
  statement_id  = "AllowExecutionFromEvents"
  action        = "lambda:InvokeFunction"
  function_name = module.lambda_function_2.lambda_function_name
  principal     = "events.amazonaws.com"
  source_arn    = aws_cloudwatch_event_rule.every_10m.arn
}


