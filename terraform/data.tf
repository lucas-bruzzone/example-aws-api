data "terraform_remote_state" "lambda" {
  backend = "s3"
  config = {
    bucket = "example-aws-terraform-terraform-state"
    key    = "example-aws-lambda/terraform.tfstate"
    region = "us-east-1"
  }
}