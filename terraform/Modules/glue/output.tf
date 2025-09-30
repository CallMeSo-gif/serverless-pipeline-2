output "glue_database_name" {
  value = aws_glue_catalog_database.parquet-db.name
}

output "glue_table_name" {
  value = aws_glue_catalog_table.parquet-table.name
}

output "glue_role_arn" {
  value = aws_iam_role.glue-role.arn
}

output "glue_crawler_name" {
  value = aws_glue_crawler.parquet-crawler.name
}
