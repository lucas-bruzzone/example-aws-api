# Cognito User Pool com MFA e políticas
resource "aws_cognito_user_pool" "main" {
  name = "${var.project_name}-users"

  password_policy {
    minimum_length    = 8
    require_lowercase = true
    require_numbers   = true
    require_symbols   = false
    require_uppercase = true
  }

  # MFA Configuration
  mfa_configuration = "OPTIONAL"

  software_token_mfa_configuration {
    enabled = true
  }

  # Account Recovery
  account_recovery_setting {
    recovery_mechanism {
      name     = "verified_email"
      priority = 1
    }
  }

  # Device Configuration
  device_configuration {
    challenge_required_on_new_device      = true
    device_only_remembered_on_user_prompt = true
  }

  # User Pool Add-ons
  user_pool_add_ons {
    advanced_security_mode = "ENFORCED"
  }

  auto_verified_attributes = ["email"]

  # Username Configuration (allow email as username)
  username_attributes = ["email"]

  # User Attribute Update Settings
  user_attribute_update_settings {
    attributes_require_verification_before_update = ["email"]
  }

  # Email Configuration
  email_configuration {
    email_sending_account = "COGNITO_DEFAULT"
  }

  tags = {
    Name = "${var.project_name}-user-pool"
  }
}

# Cognito User Pool Client
resource "aws_cognito_user_pool_client" "main" {
  name         = "${var.project_name}-app"
  user_pool_id = aws_cognito_user_pool.main.id

  explicit_auth_flows = [
    "ALLOW_USER_PASSWORD_AUTH",
    "ALLOW_REFRESH_TOKEN_AUTH",
    "ALLOW_USER_SRP_AUTH"
  ]

  generate_secret = false

  # OAuth Settings for Social Login
  supported_identity_providers = ["COGNITO", "Google"]

  callback_urls = [
    "http://localhost:3000/callback",
    var.domain_name != "" ? "https://${var.domain_name}/callback" : "https://${var.project_name}-${var.environment}-website.s3-website-${var.aws_region}.amazonaws.com/callback"
  ]

  logout_urls = [
    "http://localhost:3000/",
    var.domain_name != "" ? "https://${var.domain_name}/" : "https://${var.project_name}-${var.environment}-website.s3-website-${var.aws_region}.amazonaws.com/"
  ]

  allowed_oauth_flows_user_pool_client = true
  allowed_oauth_flows                  = ["code"]
  allowed_oauth_scopes                 = ["email", "openid", "profile"]

  # Token Validity
  access_token_validity  = 1  # 1 hour
  id_token_validity      = 1  # 1 hour
  refresh_token_validity = 30 # 30 days

  token_validity_units {
    access_token  = "hours"
    id_token      = "hours"
    refresh_token = "days"
  }

  # Prevent User Existence Errors
  prevent_user_existence_errors = "ENABLED"
}

# Google Identity Provider
resource "aws_cognito_identity_provider" "google" {
  user_pool_id  = aws_cognito_user_pool.main.id
  provider_name = "Google"
  provider_type = "Google"

  provider_details = {
    client_id                     = var.google_client_id
    client_secret                 = var.google_client_secret
    authorize_scopes              = "email openid profile"
    attributes_url                = "https://people.googleapis.com/v1/people/me?personFields="
    attributes_url_add_attributes = "true"
    authorize_url                 = "https://accounts.google.com/o/oauth2/v2/auth"
    oidc_issuer                   = "https://accounts.google.com"
    token_request_method          = "POST"
    token_url                     = "https://www.googleapis.com/oauth2/v4/token"
  }

  attribute_mapping = {
    email    = "email"
    username = "sub"
    name     = "name"
  }
}

# Cognito User Pool Domain
resource "aws_cognito_user_pool_domain" "main" {
  domain       = "${var.project_name}-${var.environment}-auth"
  user_pool_id = aws_cognito_user_pool.main.id
}

# Risk Configuration (Advanced Security Features)
resource "aws_cognito_risk_configuration" "main" {
  user_pool_id = aws_cognito_user_pool.main.id

  compromised_credentials_risk_configuration {
    actions {
      event_action = "BLOCK"
    }
  }
}

# API Gateway Authorizer
resource "aws_api_gateway_authorizer" "cognito" {
  name          = "${var.project_name}-cognito-authorizer"
  rest_api_id   = aws_api_gateway_rest_api.main.id
  type          = "COGNITO_USER_POOLS"
  provider_arns = [aws_cognito_user_pool.main.arn]
}

# ===================================
# API GATEWAY REST API
# ===================================

resource "aws_api_gateway_rest_api" "main" {
  name        = "${var.project_name}-api"
  description = "API Gateway for ${var.project_name}"

  endpoint_configuration {
    types = ["REGIONAL"]
  }
}

# ===================================
# RECURSOS (/validate)
# ===================================

# Recurso /validate
resource "aws_api_gateway_resource" "validate" {
  rest_api_id = aws_api_gateway_rest_api.main.id
  parent_id   = aws_api_gateway_rest_api.main.root_resource_id
  path_part   = "validate"
}

# Método POST /validate
resource "aws_api_gateway_method" "validate_post" {
  rest_api_id   = aws_api_gateway_rest_api.main.id
  resource_id   = aws_api_gateway_resource.validate.id
  http_method   = "POST"
  authorization = "COGNITO_USER_POOLS"
  authorizer_id = aws_api_gateway_authorizer.cognito.id
}

# Método OPTIONS /validate para CORS
resource "aws_api_gateway_method" "validate_options" {
  rest_api_id   = aws_api_gateway_rest_api.main.id
  resource_id   = aws_api_gateway_resource.validate.id
  http_method   = "OPTIONS"
  authorization = "NONE"
}

# Integração com Lambda - /validate
resource "aws_api_gateway_integration" "validate_lambda" {
  rest_api_id = aws_api_gateway_rest_api.main.id
  resource_id = aws_api_gateway_resource.validate.id
  http_method = aws_api_gateway_method.validate_post.http_method

  integration_http_method = "POST"
  type                    = "AWS_PROXY"
  uri                     = data.terraform_remote_state.lambda.outputs.lambda_invoke_arn
}

# Integração CORS - /validate
resource "aws_api_gateway_integration" "validate_options" {
  rest_api_id = aws_api_gateway_rest_api.main.id
  resource_id = aws_api_gateway_resource.validate.id
  http_method = aws_api_gateway_method.validate_options.http_method
  type        = "MOCK"

  request_templates = {
    "application/json" = jsonencode({
      statusCode = 200
    })
  }
}

# Response CORS OPTIONS - /validate
resource "aws_api_gateway_method_response" "validate_options" {
  rest_api_id = aws_api_gateway_rest_api.main.id
  resource_id = aws_api_gateway_resource.validate.id
  http_method = aws_api_gateway_method.validate_options.http_method
  status_code = "200"

  response_parameters = {
    "method.response.header.Access-Control-Allow-Headers" = true
    "method.response.header.Access-Control-Allow-Methods" = true
    "method.response.header.Access-Control-Allow-Origin"  = true
  }
}

# Integration response CORS - /validate
resource "aws_api_gateway_integration_response" "validate_options" {
  rest_api_id = aws_api_gateway_rest_api.main.id
  resource_id = aws_api_gateway_resource.validate.id
  http_method = aws_api_gateway_method.validate_options.http_method
  status_code = aws_api_gateway_method_response.validate_options.status_code

  response_parameters = {
    "method.response.header.Access-Control-Allow-Headers" = "'Content-Type,X-Amz-Date,Authorization,X-Api-Key,X-Amz-Security-Token'"
    "method.response.header.Access-Control-Allow-Methods" = "'POST,OPTIONS'"
    "method.response.header.Access-Control-Allow-Origin"  = "'*'"
  }
}

# ===================================
# RECURSOS (/properties)
# ===================================

# Recurso /properties
resource "aws_api_gateway_resource" "properties" {
  rest_api_id = aws_api_gateway_rest_api.main.id
  parent_id   = aws_api_gateway_rest_api.main.root_resource_id
  path_part   = "properties"
}

# Recurso /properties/{id}
resource "aws_api_gateway_resource" "properties_id" {
  rest_api_id = aws_api_gateway_rest_api.main.id
  parent_id   = aws_api_gateway_resource.properties.id
  path_part   = "{id}"
}

# ===================================
# MÉTODOS PARA /properties
# ===================================

# POST /properties (create_property)
resource "aws_api_gateway_method" "properties_post" {
  rest_api_id   = aws_api_gateway_rest_api.main.id
  resource_id   = aws_api_gateway_resource.properties.id
  http_method   = "POST"
  authorization = "COGNITO_USER_POOLS"
  authorizer_id = aws_api_gateway_authorizer.cognito.id
}

# GET /properties (get_properties)
resource "aws_api_gateway_method" "properties_get" {
  rest_api_id   = aws_api_gateway_rest_api.main.id
  resource_id   = aws_api_gateway_resource.properties.id
  http_method   = "GET"
  authorization = "COGNITO_USER_POOLS"
  authorizer_id = aws_api_gateway_authorizer.cognito.id
}

# OPTIONS /properties (CORS)
resource "aws_api_gateway_method" "properties_options" {
  rest_api_id   = aws_api_gateway_rest_api.main.id
  resource_id   = aws_api_gateway_resource.properties.id
  http_method   = "OPTIONS"
  authorization = "NONE"
}

# ===================================
# MÉTODOS PARA /properties/{id}
# ===================================

# PUT /properties/{id} (update_property)
resource "aws_api_gateway_method" "properties_id_put" {
  rest_api_id   = aws_api_gateway_rest_api.main.id
  resource_id   = aws_api_gateway_resource.properties_id.id
  http_method   = "PUT"
  authorization = "COGNITO_USER_POOLS"
  authorizer_id = aws_api_gateway_authorizer.cognito.id

  request_parameters = {
    "method.request.path.id" = true
  }
}

# DELETE /properties/{id} (delete_property)
resource "aws_api_gateway_method" "properties_id_delete" {
  rest_api_id   = aws_api_gateway_rest_api.main.id
  resource_id   = aws_api_gateway_resource.properties_id.id
  http_method   = "DELETE"
  authorization = "COGNITO_USER_POOLS"
  authorizer_id = aws_api_gateway_authorizer.cognito.id

  request_parameters = {
    "method.request.path.id" = true
  }
}

# OPTIONS /properties/{id} (CORS)
resource "aws_api_gateway_method" "properties_id_options" {
  rest_api_id   = aws_api_gateway_rest_api.main.id
  resource_id   = aws_api_gateway_resource.properties_id.id
  http_method   = "OPTIONS"
  authorization = "NONE"
}

# ===================================
# INTEGRAÇÕES LAMBDA PARA /properties
# ===================================

# Integração POST /properties
resource "aws_api_gateway_integration" "properties_post_lambda" {
  rest_api_id = aws_api_gateway_rest_api.main.id
  resource_id = aws_api_gateway_resource.properties.id
  http_method = aws_api_gateway_method.properties_post.http_method

  integration_http_method = "POST"
  type                    = "AWS_PROXY"
  uri                     = data.terraform_remote_state.lambda.outputs.lambda_invoke_arn
}

# Integração GET /properties
resource "aws_api_gateway_integration" "properties_get_lambda" {
  rest_api_id = aws_api_gateway_rest_api.main.id
  resource_id = aws_api_gateway_resource.properties.id
  http_method = aws_api_gateway_method.properties_get.http_method

  integration_http_method = "POST"
  type                    = "AWS_PROXY"
  uri                     = data.terraform_remote_state.lambda.outputs.lambda_invoke_arn
}

# Integração PUT /properties/{id}
resource "aws_api_gateway_integration" "properties_id_put_lambda" {
  rest_api_id = aws_api_gateway_rest_api.main.id
  resource_id = aws_api_gateway_resource.properties_id.id
  http_method = aws_api_gateway_method.properties_id_put.http_method

  integration_http_method = "POST"
  type                    = "AWS_PROXY"
  uri                     = data.terraform_remote_state.lambda.outputs.lambda_invoke_arn

  request_parameters = {
    "integration.request.path.id" = "method.request.path.id"
  }
}

# Integração DELETE /properties/{id}
resource "aws_api_gateway_integration" "properties_id_delete_lambda" {
  rest_api_id = aws_api_gateway_rest_api.main.id
  resource_id = aws_api_gateway_resource.properties_id.id
  http_method = aws_api_gateway_method.properties_id_delete.http_method

  integration_http_method = "POST"
  type                    = "AWS_PROXY"
  uri                     = data.terraform_remote_state.lambda.outputs.lambda_invoke_arn

  request_parameters = {
    "integration.request.path.id" = "method.request.path.id"
  }
}

# ===================================
# INTEGRAÇÕES CORS
# ===================================

# Integração CORS /properties
resource "aws_api_gateway_integration" "properties_options" {
  rest_api_id = aws_api_gateway_rest_api.main.id
  resource_id = aws_api_gateway_resource.properties.id
  http_method = aws_api_gateway_method.properties_options.http_method
  type        = "MOCK"

  request_templates = {
    "application/json" = jsonencode({
      statusCode = 200
    })
  }
}

# Integração CORS /properties/{id}
resource "aws_api_gateway_integration" "properties_id_options" {
  rest_api_id = aws_api_gateway_rest_api.main.id
  resource_id = aws_api_gateway_resource.properties_id.id
  http_method = aws_api_gateway_method.properties_id_options.http_method
  type        = "MOCK"

  request_templates = {
    "application/json" = jsonencode({
      statusCode = 200
    })
  }
}

# ===================================
# RESPONSES CORS
# ===================================

# Response CORS /properties
resource "aws_api_gateway_method_response" "properties_options" {
  rest_api_id = aws_api_gateway_rest_api.main.id
  resource_id = aws_api_gateway_resource.properties.id
  http_method = aws_api_gateway_method.properties_options.http_method
  status_code = "200"

  response_parameters = {
    "method.response.header.Access-Control-Allow-Headers" = true
    "method.response.header.Access-Control-Allow-Methods" = true
    "method.response.header.Access-Control-Allow-Origin"  = true
  }
}

# Response CORS /properties/{id}
resource "aws_api_gateway_method_response" "properties_id_options" {
  rest_api_id = aws_api_gateway_rest_api.main.id
  resource_id = aws_api_gateway_resource.properties_id.id
  http_method = aws_api_gateway_method.properties_id_options.http_method
  status_code = "200"

  response_parameters = {
    "method.response.header.Access-Control-Allow-Headers" = true
    "method.response.header.Access-Control-Allow-Methods" = true
    "method.response.header.Access-Control-Allow-Origin"  = true
  }
}

# ===================================
# INTEGRATION RESPONSES CORS
# ===================================

# Integration response CORS /properties
resource "aws_api_gateway_integration_response" "properties_options" {
  rest_api_id = aws_api_gateway_rest_api.main.id
  resource_id = aws_api_gateway_resource.properties.id
  http_method = aws_api_gateway_method.properties_options.http_method
  status_code = aws_api_gateway_method_response.properties_options.status_code

  response_parameters = {
    "method.response.header.Access-Control-Allow-Headers" = "'Content-Type,X-Amz-Date,Authorization,X-Api-Key,X-Amz-Security-Token'"
    "method.response.header.Access-Control-Allow-Methods" = "'GET,POST,OPTIONS'"
    "method.response.header.Access-Control-Allow-Origin"  = "'*'"
  }
}

# Integration response CORS /properties/{id}
resource "aws_api_gateway_integration_response" "properties_id_options" {
  rest_api_id = aws_api_gateway_rest_api.main.id
  resource_id = aws_api_gateway_resource.properties_id.id
  http_method = aws_api_gateway_method.properties_id_options.http_method
  status_code = aws_api_gateway_method_response.properties_id_options.status_code

  response_parameters = {
    "method.response.header.Access-Control-Allow-Headers" = "'Content-Type,X-Amz-Date,Authorization,X-Api-Key,X-Amz-Security-Token'"
    "method.response.header.Access-Control-Allow-Methods" = "'PUT,DELETE,OPTIONS'"
    "method.response.header.Access-Control-Allow-Origin"  = "'*'"
  }
}

# ===================================
# LAMBDA PERMISSIONS
# ===================================

# Permissão para API Gateway invocar Lambda (/validate)
resource "aws_lambda_permission" "api_gateway" {
  statement_id  = "AllowExecutionFromAPIGateway"
  action        = "lambda:InvokeFunction"
  function_name = data.terraform_remote_state.lambda.outputs.lambda_function_name
  principal     = "apigateway.amazonaws.com"
  source_arn    = "${aws_api_gateway_rest_api.main.execution_arn}/*/*"
}

# Permissão para novos endpoints invocarem a Lambda (/properties)
resource "aws_lambda_permission" "api_gateway_properties" {
  statement_id  = "AllowExecutionFromAPIGatewayProperties"
  action        = "lambda:InvokeFunction"
  function_name = data.terraform_remote_state.lambda.outputs.lambda_function_name
  principal     = "apigateway.amazonaws.com"
  source_arn    = "${aws_api_gateway_rest_api.main.execution_arn}/*/properties"
}

# Permissão para endpoints com ID (/properties/{id})
resource "aws_lambda_permission" "api_gateway_properties_id" {
  statement_id  = "AllowExecutionFromAPIGatewayPropertiesId"
  action        = "lambda:InvokeFunction"
  function_name = data.terraform_remote_state.lambda.outputs.lambda_function_name
  principal     = "apigateway.amazonaws.com"
  source_arn    = "${aws_api_gateway_rest_api.main.execution_arn}/*/properties/*"
}

# ===================================
# DEPLOYMENT & STAGE
# ===================================

# Deployment
resource "aws_api_gateway_deployment" "main" {
  depends_on = [
    # Recursos existentes /validate
    aws_api_gateway_method.validate_post,
    aws_api_gateway_method.validate_options,
    aws_api_gateway_integration.validate_lambda,
    aws_api_gateway_integration.validate_options,
    aws_api_gateway_method_response.validate_options,
    aws_api_gateway_integration_response.validate_options,

    # Novos recursos /properties
    aws_api_gateway_method.properties_post,
    aws_api_gateway_method.properties_get,
    aws_api_gateway_method.properties_options,
    aws_api_gateway_integration.properties_post_lambda,
    aws_api_gateway_integration.properties_get_lambda,
    aws_api_gateway_integration.properties_options,
    aws_api_gateway_method_response.properties_options,
    aws_api_gateway_integration_response.properties_options,

    # Novos recursos /properties/{id}
    aws_api_gateway_method.properties_id_put,
    aws_api_gateway_method.properties_id_delete,
    aws_api_gateway_method.properties_id_options,
    aws_api_gateway_integration.properties_id_put_lambda,
    aws_api_gateway_integration.properties_id_delete_lambda,
    aws_api_gateway_integration.properties_id_options,
    aws_api_gateway_method_response.properties_id_options,
    aws_api_gateway_integration_response.properties_id_options,

    # Google Identity Provider
    aws_cognito_identity_provider.google,
  ]

  rest_api_id = aws_api_gateway_rest_api.main.id

  triggers = {
    redeployment = sha1(jsonencode([
      # Recursos existentes
      aws_api_gateway_resource.validate.id,
      aws_api_gateway_method.validate_post.id,
      aws_api_gateway_method.validate_options.id,
      aws_api_gateway_integration.validate_lambda.id,
      aws_api_gateway_integration.validate_options.id,

      # Novos recursos /properties
      aws_api_gateway_resource.properties.id,
      aws_api_gateway_method.properties_post.id,
      aws_api_gateway_method.properties_get.id,
      aws_api_gateway_method.properties_options.id,
      aws_api_gateway_integration.properties_post_lambda.id,
      aws_api_gateway_integration.properties_get_lambda.id,
      aws_api_gateway_integration.properties_options.id,

      # Novos recursos /properties/{id}
      aws_api_gateway_resource.properties_id.id,
      aws_api_gateway_method.properties_id_put.id,
      aws_api_gateway_method.properties_id_delete.id,
      aws_api_gateway_method.properties_id_options.id,
      aws_api_gateway_integration.properties_id_put_lambda.id,
      aws_api_gateway_integration.properties_id_delete_lambda.id,
      aws_api_gateway_integration.properties_id_options.id,

      # Identity Provider
      aws_cognito_identity_provider.google.id,
    ]))
  }

  lifecycle {
    create_before_destroy = true
  }
}

# Stage
resource "aws_api_gateway_stage" "main" {
  deployment_id = aws_api_gateway_deployment.main.id
  rest_api_id   = aws_api_gateway_rest_api.main.id
  stage_name    = var.environment
}