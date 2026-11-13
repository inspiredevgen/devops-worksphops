# EN: Outputs expose values to the CLI, to scripts (`terraform output -raw`)
#     and to other configurations (Module 4: modules; Module 3: remote state).
# FR: Les sorties exposent des valeurs à la CLI, aux scripts
#     (`terraform output -raw`) et à d'autres configurations (modules 3 et 4).

output "instance_id" {
  description = "EN: EC2 instance ID / FR: ID de l'instance EC2"
  value       = aws_instance.web.id
}

output "ami_used" {
  description = "EN: AMI selected by the data source / FR: AMI choisie par la source de données"
  value       = "${data.aws_ami.al2023.id} (${data.aws_ami.al2023.name})"
}

output "public_ip" {
  description = "EN: Public IP (default subnets assign one) / FR: IP publique (attribuée par les sous-réseaux par défaut)"
  value       = aws_instance.web.public_ip
}

output "availability_zone" {
  description = "EN: AZ chosen by AWS / FR: Zone choisie par AWS"
  value       = aws_instance.web.availability_zone
}
