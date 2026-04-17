output "website_bucket_name" {
  description = "Le nom exact du bucket S3 généré"
  value       = aws_s3_bucket.static_site.id
}

output "website_bucket_arn" {
  description = "L'ARN du bucket (utile pour les politiques IAM plus tard)"
  value       = aws_s3_bucket.static_site.arn
}

output "website_bucket_domain" {
  description = "Le nom de domaine régional du bucket"
  value       = aws_s3_bucket.static_site.bucket_regional_domain_name
}

output "cloudfront_url" {
  description = "L'URL de ton site web sécurisé (HTTPS)"
  value       = "https://${aws_cloudfront_distribution.s3_distribution.domain_name}"
}