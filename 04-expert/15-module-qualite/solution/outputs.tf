output "id" {
  description = "Nom du bucket"
  value       = aws_s3_bucket.this.id
}

output "arn" {
  description = "ARN du bucket"
  value       = aws_s3_bucket.this.arn
}
