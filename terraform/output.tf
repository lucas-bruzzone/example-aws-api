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

output "validate_endpoint" {
  description = "Endpoint /validate completo"
  value       = "https://${aws_api_gateway_rest_api.main.id}.execute-api.${var.aws_region}.amazonaws.com/${var.environment}/validate"
}

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