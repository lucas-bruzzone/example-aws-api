# ===================================
# COGNITO USER POOL CONFIGURATION
# ===================================

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

# ===================================
# COGNITO USER POOL CLIENT
# ===================================

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

  # Fixed callback URLs - using localhost for development
  callback_urls = concat(
    [
      "http://localhost:3000/callback",
      "http://localhost:3000/callback.html",
      "http://localhost:5500/callback",
      "http://localhost:5500/callback.html"
    ],
    local.prod_callbacks,
    var.domain_name != "" ? [
      "https://${var.domain_name}/callback",
      "https://${var.domain_name}/callback.html"
    ] : []
  )

  logout_urls = concat(
    [
      "http://localhost:3000/",
      "http://localhost:5500/"
    ],
    local.prod_logouts,
    var.domain_name != "" ? ["https://${var.domain_name}/"] : []
  )

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

# ===================================
# GOOGLE IDENTITY PROVIDER
# ===================================

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

# ===================================
# COGNITO USER POOL DOMAIN
# ===================================

resource "aws_cognito_user_pool_domain" "main" {
  domain       = "${replace(var.project_name, "aws", "cloud")}-${var.environment}-auth"
  user_pool_id = aws_cognito_user_pool.main.id
}

# ===================================
# RISK CONFIGURATION
# ===================================

resource "aws_cognito_risk_configuration" "main" {
  user_pool_id = aws_cognito_user_pool.main.id

  compromised_credentials_risk_configuration {
    actions {
      event_action = "BLOCK"
    }
  }
}