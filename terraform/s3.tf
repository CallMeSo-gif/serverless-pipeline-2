
resource "aws_s3_bucket" "tf_bucket" {
  bucket = var.bucketA
   
}

resource "aws_s3_bucket" "tf_bucket_2" {
  bucket = var.bucketB
   
}