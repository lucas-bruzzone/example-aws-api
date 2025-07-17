# ===================================
# API GATEWAY OUTPUTS
# ===================================

output "api_gateway_id" {
  description = "ID do API Gateway"
  value       = aws_api_gateway_rest_api.main.id
}

output "api_gateway_root_resource_id" {
  description = "ID do recurso raiz do API Gateway"
  value       = aws_api_gateway_rest_api.main.root_resource_id
}

output "api_gateway_execution_arn" {
  description = "ARN de execução do API Gateway"
  value       = aws_api_gateway_rest_api.main.execution_arn
}

output "api_gateway_url" {
  description = "URL completa do API Gateway"
  value       = "https://${aws_api_gateway_rest_api.main.id}.execute-api.${var.aws_region}.amazonaws.com/${var.environment}"
}

# ===================================
# ENDPOINTS ESPECÍFICOS
# ===================================

output "properties_endpoint" {
  description = "Endpoint /properties completo"
  value       = "https://${aws_api_gateway_rest_api.main.id}.execute-api.${var.aws_region}.amazonaws.com/${var.environment}/properties"
}

output "properties_id_endpoint" {
  description = "Endpoint /properties/{id} completo"
  value       = "https://${aws_api_gateway_rest_api.main.id}.execute-api.${var.aws_region}.amazonaws.com/${var.environment}/properties/{id}"
}

# ===================================
# COGNITO OUTPUTS
# ===================================

output "cognito_user_pool_id" {
  description = "ID do Cognito User Pool"
  value       = aws_cognito_user_pool.main.id
}

output "cognito_client_id" {
  description = "ID do Cognito App Client"
  value       = aws_cognito_user_pool_client.main.id
}

output "cognito_region" {
  description = "Região do Cognito"
  value       = var.aws_region
}

output "cognito_user_pool_arn" {
  description = "ARN do Cognito User Pool"
  value       = aws_cognito_user_pool.main.arn
}

# ===================================
# INFORMAÇÕES DE INTEGRAÇÃO
# ===================================

output "lambda_integration_info" {
  description = "Informações da integração com Lambda"
  value = {
    lambda_function_name = data.terraform_remote_state.lambda.outputs.lambda_function_name
    lambda_invoke_arn    = data.terraform_remote_state.lambda.outputs.lambda_invoke_arn
  }
}

# ===================================
# RESUMO DA API
# ===================================

output "api_summary" {
  description = "Resumo completo da API"
  value = {
    api_name        = "${var.project_name}-api"
    environment     = var.environment
    region          = var.aws_region
    base_url        = "https://${aws_api_gateway_rest_api.main.id}.execute-api.${var.aws_region}.amazonaws.com/${var.environment}"
    authentication  = "AWS Cognito User Pools"
    cors_enabled    = true
    total_endpoints = 6 # 5 properties endpoints
    lambda_backend  = data.terraform_remote_state.lambda.outputs.lambda_function_name
  }
}