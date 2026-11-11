output "url" {
  value = "http://${aws_instance.this.public_ip}"
}

output "instance_id" {
  value = aws_instance.this.id
}

# EN: Exposed so unit tests can inspect the rendered script (the provider may store user_data as a hash).
# FR : Exposé pour que les tests unitaires inspectent le script rendu (le provider peut stocker user_data sous forme de hachage).
output "rendered_user_data" {
  value = local.user_data
}
