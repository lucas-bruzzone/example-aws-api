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

resource "aws_lambda_permission" "api_gateway_properties_report" {
  statement_id  = "AllowExecutionFromAPIGatewayPropertiesReport"
  action        = "lambda:InvokeFunction"
  function_name = data.terraform_remote_state.lambda.outputs.lambda_function_name
  principal     = "apigateway.amazonaws.com"
  source_arn    = "${aws_api_gateway_rest_api.main.execution_arn}/*/properties/report"
}

# ===================================
# DEPLOYMENT & STAGE
# ===================================

resource "aws_api_gateway_deployment" "main" {
  depends_on = [
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

    # Recursos /properties/report
    aws_api_gateway_method.properties_report_post,
    aws_api_gateway_method.properties_report_options,
    aws_api_gateway_integration.properties_report_post_lambda,
    aws_api_gateway_integration.properties_report_options,
    aws_api_gateway_method_response.properties_report_options,
    aws_api_gateway_integration_response.properties_report_options,

    # Method responses CORS para métodos principais
    aws_api_gateway_method_response.properties_get_200,
    aws_api_gateway_method_response.properties_post_200,
    aws_api_gateway_method_response.properties_id_put_200,
    aws_api_gateway_method_response.properties_id_delete_200,
    aws_api_gateway_method_response.properties_report_post_200,

    # Integration responses CORS para métodos principais
    aws_api_gateway_integration_response.properties_get_200,
    aws_api_gateway_integration_response.properties_post_200,
    aws_api_gateway_integration_response.properties_id_put_200,
    aws_api_gateway_integration_response.properties_id_delete_200,
    aws_api_gateway_integration_response.properties_report_post_200,

    # Google Identity Provider
    aws_cognito_identity_provider.google,
  ]

  rest_api_id = aws_api_gateway_rest_api.main.id

  triggers = {
    redeployment = sha1(jsonencode([
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

      # Recursos /properties/report
      aws_api_gateway_resource.properties_report.id,
      aws_api_gateway_method.properties_report_post.id,
      aws_api_gateway_method.properties_report_options.id,
      aws_api_gateway_integration.properties_report_post_lambda.id,
      aws_api_gateway_integration.properties_report_options.id,

      # CORS responses
      aws_api_gateway_method_response.properties_get_200.id,
      aws_api_gateway_method_response.properties_post_200.id,
      aws_api_gateway_method_response.properties_id_put_200.id,
      aws_api_gateway_method_response.properties_id_delete_200.id,
      aws_api_gateway_method_response.properties_report_post_200.id,
      aws_api_gateway_integration_response.properties_get_200.id,
      aws_api_gateway_integration_response.properties_post_200.id,
      aws_api_gateway_integration_response.properties_id_put_200.id,
      aws_api_gateway_integration_response.properties_id_delete_200.id,
      aws_api_gateway_integration_response.properties_report_post_200.id,

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