# -----------------------------------------------------------------------------
# Lab 3.I-AWS (part 2) — An application that stores its state remotely
# Lab 3.I-AWS (partie 2) — Une application qui stocke son état à distance
#
# EN: time_sleep keeps `apply` running long enough to SEE state locking
#     in action from a second terminal. Cost: $0.
# FR: time_sleep fait durer `apply` assez longtemps pour VOIR le verrouillage
#     de l'état depuis un second terminal. Coût : 0 $.
# -----------------------------------------------------------------------------

variable "aws_region" {
  description = "EN: AWS region / FR: Région AWS"
  type        = string
  default     = "ca-central-1"
}

variable "release" {
  description = "EN: Release label — change it to trigger a new apply / FR: Étiquette de version — changez-la pour déclencher un nouvel apply"
  type        = string
  default     = "v1"
}

variable "sleep_duration" {
  description = "EN: How long apply holds the lock / FR: Durée pendant laquelle apply garde le verrou"
  type        = string
  default     = "90s"
}

resource "aws_ssm_parameter" "release" {
  name  = "/tf-lab/m03/remote-state-demo/release"
  type  = "String"
  value = var.release
}

# EN: Re-created whenever `release` changes → each release apply waits.
# FR: Recréé à chaque changement de `release` → chaque apply de version attend.
resource "time_sleep" "hold_lock" {
  create_duration = var.sleep_duration

  triggers = {
    release = var.release
  }

  depends_on = [aws_ssm_parameter.release]
}

output "release" {
  description = "EN: Current release / FR: Version actuelle"
  value       = aws_ssm_parameter.release.value
}
