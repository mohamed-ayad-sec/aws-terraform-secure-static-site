variable "aws_region" {
  description = "La région AWS où les ressources seront déployées"
  type        = string
  default     = "eu-west-3"
}

variable "project_name" {
  description = "Le nom du projet"
  type        = string
  default     = "mohamed-secure-site"
}

variable "environment" {
  description = "L'environnement (dev, staging, prod)"
  type        = string
  default     = "dev"
}

variable "common_tags" {
  description = "Tags à appliquer à toutes les ressources"
  type        = map(string)
  default = {
    Project     = "SecureStaticSite"
    Owner       = "Mohamed"
    ManagedBy   = "Terraform"
    Environment = "dev"
  }
}