
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
          "s3:DeleteObject",
          "s3:GetBucketLocation",
          "s3:CreateBucket"
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

# Attach the AWS managed policy for querying Athenae
resource "aws_iam_role_policy_attachment" "example-attach2" {
  role       = aws_iam_role.glue-role.name
  policy_arn = "arn:aws:iam::aws:policy/AmazonAthenaFullAccess"
}




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

# Define the schema of the table
  storage_descriptor {
    location      = "s3://${var.s3_bucket2}/processed/"
    input_format  = "org.apache.hadoop.hive.ql.io.parquet.MapredParquetInputFormat"
    output_format = "org.apache.hadoop.hive.ql.io.parquet.MapredParquetOutputFormat"
    #ser_de = serialization / deserialization
    ser_de_info {
      serialization_library = "org.apache.hadoop.hive.ql.io.parquet.serde.ParquetHiveSerDe"

      parameters = {
        "serialization.format" = 1
      }
    }

    columns {
      name = "departement"
      type = "string"
    } 
    columns {
      name = "role"
      type = "string"
    }
    columns {
      name = "salaire"
      type = "string"
    }
    columns {
      name = "salaire_annuel_eur"
      type = "int"
    }
  }
    
}


# Now build the Crawler
resource "aws_glue_crawler" "parquet-crawler" {
  database_name = var.database_name
  name          = var.crawler_name
  role          = aws_iam_role.glue-role.arn
  description   = "Crawler for parquet files in the S3 bucket"

  s3_target {
    path = "s3://${var.s3_bucket2}/processed/"
  }

  ## I would enforce the schema and I don't want the crawler to modify it.
  ## So I set both update and delete behavior to LOG
  schema_change_policy {
  update_behavior = "LOG"
  delete_behavior = "LOG"
}

}



# AWS Glue JOB 
resource "aws_glue_job" "etl_job" {
  name              = "my-etl-job"
  description       = "A glue ETL job to read the data fromm the bucket, transform it and write to another bucket"
  role_arn          = aws_iam_role.glue-role.arn
    
  command {
    script_location = "s3://${var.s3_bucket2}/jobs/athena-spark.py"
    name            = "glueet1"
    #glueet1 for pyspark, pythonshell for plain python and gluestreaming for streaming jobs 
    python_version  = "3"
  }

  glue_version      = "5.0"
  max_retries       = 0 #no automatic retries
  timeout           = 2880 # 24hours before the job is stopped
  number_of_workers = 2
  worker_type = "G.1X"
 
  #max_capacity = 1 only for pythonshell jobs
  execution_class   = "STANDARD"

  default_arguments = {
    "--DATABASE_NAME"          = var.database_name
    "--TABLE_NAME"             = var.table_name
    "--OUTPUT_BUCKET"          = var.s3_bucket2
    "--OUTPUT_PREFIX"          = "glue-processed-athena/"
    "--job-language"     = "python"
    "--ENV"              = "dev"
    "--AWS_DEFAULT_REGION" = var.aws_region
  }

  tags = {
    "Description" = "Activite 3 avec Glue",
    "Owner"       = "sfeuvouka"
  }
}

/*

resource "aws_glue_trigger" "my_trigger" {
  name     = "my-glue-trigger"
  type     = "SCHEDULED"
  schedule = "cron(0/5 * * * ? *)"  # Every 5 minutes

  actions {
    job_name = aws_glue_job.etl_job.name
  }

  start_on_creation = false
}
*/




# Workgroup for Athena
resource "aws_athena_workgroup" "example" {
  name = "example_workgroup"

  configuration {
    enforce_workgroup_configuration = true
    result_configuration {
      output_location = "s3://${var.s3_bucket2}/athena-queries/"
      encryption_configuration {
        encryption_option = "SSE_S3"
      }
    }
  }
}
/*
resource "aws_athena_named_query" "foo" {
  name      = "bar"
  workgroup = aws_athena_workgroup.example.id
  database  = var.database_name
  query     = "SELECT * FROM ${var.database_name}.${var.table_name} limit 2;"
}

*/

