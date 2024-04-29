resource "aws_s3_bucket" "my_s3_bucket" {
  bucket = "my-unique-bucket-name"
  tags = {
    Name        = "My bucket"
    Environment = "Dev"
  }
}
