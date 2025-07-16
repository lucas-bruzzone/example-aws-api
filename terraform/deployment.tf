# ===================================
# LAMBDA PERMISSIONS
# ===================================

resource "aws_lambda_permission" "api_gateway" {
  statement_id  = "AllowExecutionFromAPIGateway"
  action        = "lambda:InvokeFunction"
  function_name = data.terraform_remote_state.lambda.outputs.lambda_function_name
  principal     = "apigateway.amazonaws.com"
  source_arn    = "${aws_api_gateway_rest_api.main.execution_arn}/*/*"
}

resource "aws_lambda_permission" "api_gateway_properties" {
  statement_id  = "AllowExecutionFromAPIGatewayProperties"
  action        = "lambda:InvokeFunction"
  function_name = data.terraform_remote_state.lambda.outputs.lambda_function_name
  principal     = "apigateway.amazonaws.com"
  source_arn    = "${aws_api_gateway_rest_api.main.execution_arn}/*/properties"
}

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

resource "aws_api_gateway_deployment" "main" {
  depends_on = [
    # Recursos /validate
    aws_api_gateway_method.validate_post,
    aws_api_gateway_method.validate_options,
    aws_api_gateway_integration.validate_lambda,
    aws_api_gateway_integration.validate_options,
    aws_api_gateway_method_response.validate_options,
    aws_api_gateway_integration_response.validate_options,

    # Recursos /properties
    aws_api_gateway_method.properties_post,
    aws_api_gateway_method.properties_get,
    aws_api_gateway_method.properties_options,
    aws_api_gateway_integration.properties_post_lambda,
    aws_api_gateway_integration.properties_get_lambda,
    aws_api_gateway_integration.properties_options,
    aws_api_gateway_method_response.properties_options,
    aws_api_gateway_integration_response.properties_options,

    # Recursos /properties/{id}
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

      # Recursos /properties
      aws_api_gateway_resource.properties.id,
      aws_api_gateway_method.properties_post.id,
      aws_api_gateway_method.properties_get.id,
      aws_api_gateway_method.properties_options.id,
      aws_api_gateway_integration.properties_post_lambda.id,
      aws_api_gateway_integration.properties_get_lambda.id,
      aws_api_gateway_integration.properties_options.id,

      # Recursos /properties/{id}
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

resource "aws_api_gateway_stage" "main" {
  deployment_id = aws_api_gateway_deployment.main.id
  rest_api_id   = aws_api_gateway_rest_api.main.id
  stage_name    = var.environment
}