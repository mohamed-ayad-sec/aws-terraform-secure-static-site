# 1. Générer un suffixe aléatoire
resource "random_id" "bucket_suffix" {
  byte_length = 4
}

# ==========================================
# BUCKET PRINCIPAL (Hébergement du site)
# ==========================================

resource "aws_s3_bucket" "static_site" {
  # checkov:skip=CKV_AWS_144: "Réplication non-essentielle pour un portfolio"
  # checkov:skip=CKV_AWS_145: "AES256 est suffisant, KMS non requis ici"
  # checkov:skip=CKV_AWS_18: "Logging activé via ressource séparée"
  # checkov:skip=CKV_AWS_21: "Versioning activé via ressource séparée"
  # checkov:skip=CKV_AWS_19: "Encryption activée via ressource séparée"
  # checkov:skip=CKV2_AWS_6: "Public access block activé via ressource séparée"
  # checkov:skip=CKV2_AWS_61: "Lifecycle activé via ressource séparée"
  # checkov:skip=CKV2_AWS_62: "Notifications non requises"

  bucket = "${var.project_name}-${var.environment}-${random_id.bucket_suffix.hex}"
  tags   = var.common_tags
}

resource "aws_s3_bucket_public_access_block" "static_site_block" {
  bucket                  = aws_s3_bucket.static_site.id
  block_public_acls       = true
  block_public_policy     = true
  ignore_public_acls      = true
  restrict_public_buckets = true
}

resource "aws_s3_bucket_versioning" "static_site_versioning" {
  bucket = aws_s3_bucket.static_site.id
  versioning_configuration { status = "Enabled" }
}

resource "aws_s3_bucket_server_side_encryption_configuration" "static_site_encryption" {
  bucket = aws_s3_bucket.static_site.id
  rule {
    apply_server_side_encryption_by_default { sse_algorithm = "AES256" }
  }
}

resource "aws_s3_bucket_logging" "static_site_logging" {
  bucket        = aws_s3_bucket.static_site.id
  target_bucket = aws_s3_bucket.logs.id
  target_prefix = "log/"
}

resource "aws_s3_bucket_lifecycle_configuration" "static_site_lifecycle" {
  bucket = aws_s3_bucket.static_site.id
  rule {
    id     = "cleanup-rule"
    status = "Enabled"
    filter {}
    noncurrent_version_expiration { noncurrent_days = 90 }
    abort_incomplete_multipart_upload { days_after_initiation = 7 }
  }
}

# ==========================================
# BUCKET DE LOGS (Audit trail)
# ==========================================

resource "aws_s3_bucket" "logs" {
  # checkov:skip=CKV_AWS_144: "Idem bucket principal"
  # checkov:skip=CKV_AWS_145: "Idem bucket principal"
  # checkov:skip=CKV_AWS_18: "Pas de logging sur le bucket de logs"
  # checkov:skip=CKV_AWS_21: "Versioning activé via ressource séparée"
  # checkov:skip=CKV_AWS_19: "Encryption activée via ressource séparée"
  # checkov:skip=CKV2_AWS_6: "Public access block activé via ressource séparée"
  # checkov:skip=CKV2_AWS_61: "Lifecycle activé via ressource séparée"
  # checkov:skip=CKV2_AWS_62: "Idem bucket principal"

  bucket = "${var.project_name}-logs-${random_id.bucket_suffix.hex}"
  tags   = var.common_tags
}

resource "aws_s3_bucket_public_access_block" "logs_block" {
  bucket                  = aws_s3_bucket.logs.id
  block_public_acls       = true
  block_public_policy     = true
  ignore_public_acls      = true
  restrict_public_buckets = true
}

resource "aws_s3_bucket_versioning" "logs_versioning" {
  bucket = aws_s3_bucket.logs.id
  versioning_configuration { status = "Enabled" }
}

resource "aws_s3_bucket_server_side_encryption_configuration" "logs_encryption" {
  bucket = aws_s3_bucket.logs.id
  rule {
    apply_server_side_encryption_by_default { sse_algorithm = "AES256" }
  }
}

resource "aws_s3_bucket_lifecycle_configuration" "logs_lifecycle" {
  bucket = aws_s3_bucket.logs.id
  rule {
    id     = "log-retention"
    status = "Enabled"
    filter {}
    expiration { days = 365 }
    abort_incomplete_multipart_upload { days_after_initiation = 7 }
  }
}

# ==========================================
# CLOUDFRONT (Distribution & Sécurité réseau)
# ==========================================

resource "aws_cloudfront_origin_access_control" "s3_oac" {
  name                              = "${var.project_name}-oac"
  description                       = "OAC pour S3"
  origin_access_control_origin_type = "s3"
  signing_behavior                  = "always"
  signing_protocol                  = "sigv4"
}

resource "aws_cloudfront_distribution" "s3_distribution" {
  # checkov:skip=CKV_AWS_86: "Logging CloudFront désactivé (Free Tier)"
  # checkov:skip=CKV_AWS_310: "Domaine par défaut utilisé"
  # checkov:skip=CKV_AWS_305: "WAF non configuré pour cette étape"

  enabled             = true
  is_ipv6_enabled     = true
  default_root_object = "index.html"

  origin {
    domain_name              = aws_s3_bucket.static_site.bucket_regional_domain_name
    origin_id                = "S3-${aws_s3_bucket.static_site.id}"
    origin_access_control_id = aws_cloudfront_origin_access_control.s3_oac.id
  }

  default_cache_behavior {
    allowed_methods  = ["GET", "HEAD"]
    cached_methods   = ["GET", "HEAD"]
    target_origin_id = "S3-${aws_s3_bucket.static_site.id}"

    forwarded_values {
      query_string = false
      cookies { forward = "none" }
    }

    viewer_protocol_policy = "redirect-to-https"
    min_ttl                = 0
    default_ttl            = 3600
    max_ttl                = 86400
  }

  restrictions {
    geo_restriction { restriction_type = "none" }
  }

  viewer_certificate {
    cloudfront_default_certificate = true
    minimum_protocol_version       = "TLSv1.2_2021"
  }

  tags = var.common_tags
}

# ==========================================
# IAM (Autoriser CloudFront à lire S3)
# ==========================================

resource "aws_s3_bucket_policy" "allow_access_from_cloudfront" {
  bucket = aws_s3_bucket.static_site.id
  policy = data.aws_iam_policy_document.allow_access_from_cloudfront.json
}

data "aws_iam_policy_document" "allow_access_from_cloudfront" {
  statement {
    principals {
      type        = "Service"
      identifiers = ["cloudfront.amazonaws.com"]
    }
    actions   = ["s3:GetObject"]
    resources = ["${aws_s3_bucket.static_site.arn}/*"]
    condition {
      test     = "StringEquals"
      variable = "AWS:SourceArn"
      values   = [aws_cloudfront_distribution.s3_distribution.arn]
    }
  }
}