resource "random_id" "bucket_suffix" {
  byte_length = 4
}


      
data "aws_iam_policy_document" "bucket_policy_document" {
  statement {
    actions = ["s3:GetObject", "s3:GetObjectVersion"]
    resources = ["${aws_s3_bucket.bucket.arn}/*"]
    principals {
      type = "*"
      identifiers = ["*"]
    }
 }
}
      
resource "aws_s3_bucket" "bucket" {
  bucket = "test-website-${lower(random_id.bucket_suffix.hex)}"
  acl    = "public-read"

  website {
    index_document = "index.html"
    error_document = "error.html"
  }
}

      
resource "aws_s3_bucket_policy" "bucket_policy" {
  bucket = aws_s3_bucket.bucket.id
  policy = data.aws_iam_policy_document.bucket_policy_document.json
}



