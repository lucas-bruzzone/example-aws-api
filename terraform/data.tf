data "terraform_remote_state" "lambda" {
  backend = "s3"
  config = {
    bucket = "example-aws-terraform-terraform-state"
    key    = "example-aws-lambda/terraform.tfstate"
    region = "us-east-1"
  }
}

# Data source para pegar CloudFront domain
data "terraform_remote_state" "cloudfront" {
  backend = "s3"
  config = {
    bucket = "example-aws-terraform-terraform-state"
    key    = "example-aws-cloudfront/terraform.tfstate"
    region = "us-east-1"
  }
}

locals {
  # URLs de desenvolvimento - usando apenas localhost (Cognito permite HTTP com localhost)
  dev_urls = [
    "http://localhost:3000",
    "http://localhost:5500"
  ]

  callback_paths = ["/callback", "/callback.html"]
  logout_paths   = ["/"]

  # URLs de produção
  prod_base_url = try(data.terraform_remote_state.cloudfront.outputs.cloudfront_url, "")

  # Gerar todas as combinações
  dev_callbacks = flatten([
    for base in local.dev_urls : [
      for path in local.callback_paths : "${base}${path}"
    ]
  ])

  prod_callbacks = local.prod_base_url != "" ? [
    for path in local.callback_paths : "${local.prod_base_url}${path}"
  ] : []

  dev_logouts  = [for base in local.dev_urls : "${base}/"]
  prod_logouts = local.prod_base_url != "" ? ["${local.prod_base_url}/"] : []
}