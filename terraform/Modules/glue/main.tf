
# IAM Role for Glue Crawler
resource "aws_iam_role" "glue-role" { 
  name = var.role_name

  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Action = "sts:AssumeRole"
        Effect = "Allow"
        Principal = {
          Service = "glue.amazonaws.com"
        }
      },
    ]
  })
}



resource "aws_iam_policy" "glue-policy" {
  name        = "example-policy"
  description = "IAM policy for Glue Crawler to access S3 and CloudWatch"

  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Effect = "Allow"
        Action = [
          "s3:ListBucket",
          "s3:GetObject",
          "s3:PutObject",
          "s3:DeleteObject"
        ]
        Resource = [
          "arn:aws:s3:::${var.s3_bucket1}/*",
          "arn:aws:s3:::${var.s3_bucket2}/*",
          "arn:aws:s3:::${var.s3_bucket1}",
          "arn:aws:s3:::${var.s3_bucket2}"
        ]
      },
      {
        Effect = "Allow"
        Action = [
          "logs:CreateLogGroup",
          "logs:CreateLogStream",
          "logs:PutLogEvents"
        ]
        Resource = "*"
      },
      {
        Effect = "Allow"
        Action = [
          "glue:*"
        ]
        Resource = "*"
      }
    ]
  })
}

# Attach the AWS managed policy for Glue service
resource "aws_iam_role_policy_attachment" "example-attach" {
  role       = aws_iam_role.glue-role.name
  policy_arn = aws_iam_policy.glue-policy.arn
}


/*


resource "aws_s3_object" "glue_etl_script" {
  bucket = aws_s3_bucket.aws_glue_job.id
  key    = "jobs/etl_job.py"
  source = "jobs/etl_job.py" # Make sure this file exists locally
}

*/

# Create a Glue Catalog Database
resource "aws_glue_catalog_database" "parquet-db" {
    name = var.database_name
    description = "Database for parquet files"
    create_table_default_permission {
        permissions = ["SELECT"]

        # TODO , réduire l'accès au crawler et au glue job (à revoir)
        principal {
        data_lake_principal_identifier = "IAM_ALLOWED_PRINCIPALS"
        }
    }
}


# Create the catalog table 
resource "aws_glue_catalog_table" "parquet-table" {
  name          = var.table_name
  database_name = aws_glue_catalog_database.parquet-db.name

  # Try to understand these lines too.
  table_type = "EXTERNAL_TABLE"
  parameters = {
    EXTERNAL              = "TRUE"
    "parquet.compression" = "SNAPPY"
  }

/*
  # Only useful for Athena, not really for Glue Crawler. So I'll give up.
  storage_descriptor {
    location      = "s3://my-bucket/event-streams/my-stream"
    input_format  = "org.apache.hadoop.hive.ql.io.parquet.MapredParquetInputFormat"
    output_format = "org.apache.hadoop.hive.ql.io.parquet.MapredParquetOutputFormat"

    ser_de_info {
      name                  = "my-stream"
      serialization_library = "org.apache.hadoop.hive.ql.io.parquet.serde.ParquetHiveSerDe"

      parameters = {
        "serialization.format" = 1
      }
    }
  }
  */
}


# Now build the Crawler
resource "aws_glue_crawler" "parquet-crawler" {
  database_name = var.database_name
  name          = var.crawler_name
  role          = aws_iam_role.glue-role.arn
  description   = "Crawler for parquet files in the S3 bucket"

  s3_target {
    path = var.s3_bucket2
  }

  table_prefix = "parquet_"
}



# AWS Glue JOB 
resource "aws_glue_job" "etl_job" {
  name              = "my-etl-job"
  description       = "A glue ETL job to read the data fromm dthe bucket, transform it and write to another bucket"
  role_arn          = aws_iam_role.glue-role.arn
  
  command {
    script_location = "s3://${var.s3_bucket2}/jobs/etl-job.py"
    name            = "pythonshell"
    #glueet1 for pyspark, pythonshell for plain python and gluestreaming for streaming jobs 
    python_version  = "3"
  }

  notification_property {
    notify_delay_after = 3 # delay in minutes
  }


  /*
  execution_property {
    max_concurrent_runs = 1
  }
*/
  glue_version      = "5.0"
  max_retries       = 0 #no automatic retries
  timeout           = 2880 # 24hours before the job is stopped
  
  //number_of_workers = 2
  //worker_type       = "G.1X"
  max_capacity = 1
  execution_class   = "STANDARD"


  tags = {
    "Description" = "Activite 3 avec Glue",
    "Workers"     = "2",
    "Type"        = "G.1X"
  }
}
