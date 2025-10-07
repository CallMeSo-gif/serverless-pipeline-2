



module "glue" {
    source = "./Modules/glue"
    database_name = "raw_data_db"
    table_name    = "raw_table"
    role_name     = "glue-role"
    crawler_name  = "raw-data-crawler"
    s3_bucket1 = aws_s3_bucket.tf_bucket.id
    s3_bucket2 = aws_s3_bucket.tf_bucket_2.id
    athena_role_name = "athena-role"
    aws_region = var.region

}