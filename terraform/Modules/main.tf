
# IAM Role for Glue Crawler
resource "aws_iam_role" "glue-role" { 
  name = "glue-role"

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
          "${aws_s3_bucket.tf_bucket_2.arn}",
          "${aws_s3_bucket.tf_bucket_2.arn}/*",
          "${aws_s3_bucket.tf_bucket_2.arn}",
          "${aws_s3_bucket.tf_bucket_2.arn}/*"
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
  role       = aws_iam_role.example.name
  policy_arn = aws_iam_policy.glue-policy.arn
}




# AWS Glue JOB 
resource "aws_glue_job" "etl_job" {
  name              = "etl-job"
  description       = "A glue ETL job to read the data fromm dthe bucket, transform it and write to another bucket"
  role_arn          = aws_iam_role.glue-role.arn
  
  command {
    script_location = "s3://${aws_s3_bucket.glue_scripts.bucket}/jobs/etl_job.py"
    name            = "glueetl"
    python_version  = "3"
  }

  notification_property {
    notify_delay_after = 3 # delay in minutes
  }

  default_arguments = {
    "--job-language"                     = "python"
    "--continuous-log-logGroup"          = "/aws-glue/jobs"
    "--enable-continuous-cloudwatch-log" = "true"
    "--enable-continuous-log-filter"     = "true"
    "--enable-metrics"                   = ""
    "--enable-auto-scaling"              = "true"
  }

  execution_property {
    max_concurrent_runs = 1
  }

  glue_version      = "5.0"
  max_retries       = 0
  timeout           = 2880
  number_of_workers = 2
  worker_type       = "G.1X"
  connections       = [aws_glue_connection.example.name]
  execution_class   = "STANDARD"


  tags = {
    "Description" = "Activite 3 avec Glue"
  }
}


resource "aws_s3_object" "glue_etl_script" {
  bucket = aws_s3_bucket.glue_scripts.id
  key    = "jobs/etl_job.py"
  source = "jobs/etl_job.py" # Make sure this file exists locally
}


# Create a Glue Catalog Database
resource "aws_glue_catalog_database" "parquet-db" {
    name = "MyParquetFilesDB"

    /* Try to understand what these lines do */
    create_table_default_permission {
        permissions = ["SELECT"]

        principal {
        data_lake_principal_identifier = "IAM_ALLOWED_PRINCIPALS"
        }
    }
}


# Create the catalog table 
resource "aws_glue_catalog_table" "parquet-table" {
  name          = "MyParquetTable"
  database_name = "MyParquetFilesDB"

  # Try to understand these lines too.
  table_type = "EXTERNAL_TABLE"

  parameters = {
    EXTERNAL              = "TRUE"
    "parquet.compression" = "SNAPPY"
  }

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

    columns {
      name = "my_string"
      type = "string"
    }

    columns {
      name = "my_double"
      type = "double"
    }

    columns {
      name    = "my_date"
      type    = "date"
      comment = ""
    }

    columns {
      name    = "my_bigint"
      type    = "bigint"
      comment = ""
    }

    columns {
      name    = "my_struct"
      type    = "struct<my_nested_string:string>"
      comment = ""
    }
  }
}


# Now build the Crawler
resource "aws_glue_crawler" "parquet-crawler" {
  database_name = aws_glue_catalog_database.parquet-db.name
  name          = "parquet-crawler"
  role          = aws_iam_role.example.arn

  catalog_target {
    database_name = aws_glue_catalog_database.parquet-db.name
    tables        = [aws_glue_catalog_table.parquet-table.name]
  }

  schema_change_policy {
    delete_behavior = "LOG"
  }

  configuration = <<EOF
{
  "Version":1.0,
  "Grouping": {
    "TableGroupingPolicy": "CombineCompatibleSchemas"
  }
}
EOF
}
