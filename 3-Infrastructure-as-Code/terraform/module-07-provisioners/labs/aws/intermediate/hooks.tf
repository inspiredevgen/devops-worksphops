# -----------------------------------------------------------------------------
# Lab 7.I-AWS — Provisioners, used SAFELY
# Lab 7.I-AWS — Les provisioners, utilisés en TOUTE SÉCURITÉ
#
# EN: Rules applied here:
#     1. Attach provisioners to terraform_data, NOT to the instance: if a
#        provisioner fails, only the cheap terraform_data is TAINTED — the
#        instance is not destroyed and recreated.
#     2. Control re-runs explicitly with triggers_replace.
#     3. Pass values through `environment`, not string interpolation into
#        shell code (avoids quoting and injection bugs).
#     4. Prefer a RESOURCE (local_file) over a script that writes files.
# FR: Règles appliquées ici :
#     1. Attacher les provisioners à terraform_data, PAS à l'instance : si un
#        provisioner échoue, seul le terraform_data (peu coûteux) est MARQUÉ
#        « tainted » — l'instance n'est pas détruite puis recréée.
#     2. Contrôler les réexécutions explicitement avec triggers_replace.
#     3. Passer les valeurs via `environment`, et non par interpolation dans
#        le code shell (évite les bogues de guillemets et d'injection).
#     4. Préférer une RESSOURCE (local_file) à un script qui écrit des fichiers.
#
#     ⚠️ local-exec runs on YOUR machine: these use bash (Windows → Git Bash/WSL).
#     ⚠️ local-exec s'exécute sur VOTRE machine : bash requis (Windows → Git Bash/WSL).
# -----------------------------------------------------------------------------

# =============================================================================
# 1. Smoke test — wait until the site answers HTTP 200
#    Test de fumée — attendre que le site réponde HTTP 200
# =============================================================================
resource "terraform_data" "smoke_test" {
  # EN: Re-run when the instance is replaced OR the probed port changes.
  # FR: Réexécuter quand l'instance est remplacée OU que le port testé change.
  triggers_replace = [aws_instance.web.id, var.smoke_test_port]

  provisioner "local-exec" {
    interpreter = ["bash", "-c"]

    environment = {
      URL      = "http://${aws_instance.web.public_ip}:${var.smoke_test_port}/"
      ATTEMPTS = var.smoke_test_attempts
    }

    # EN: In a heredoc, %{ starts a Terraform directive → write %%{ for curl.
    # FR: Dans un heredoc, %{ ouvre une directive Terraform → écrivez %%{ pour curl.
    command = <<-EOT
      echo "Smoke test: $URL"
      for i in $(seq 1 "$ATTEMPTS"); do
        code=$(curl -s -o /dev/null -m 5 -w '%%{http_code}' "$URL" || true)
        if [ "$code" = "200" ]; then echo "OK: HTTP 200 after $i attempt(s)"; exit 0; fi
        echo "  attempt $i: HTTP $code - waiting 5 s"
        sleep 5
      done
      echo "FAIL: $URL never returned HTTP 200"
      exit 1
    EOT
  }
}

# =============================================================================
# 2. Audit trail — a create-time AND a destroy-time provisioner
#    Piste d'audit — un provisioner à la création ET un à la destruction
# =============================================================================
resource "terraform_data" "audit" {
  # EN: Destroy-time provisioners may only use `self` → store what they need in input.
  # FR: Les provisioners de destruction ne peuvent utiliser que `self` → stocker le nécessaire dans input.
  input = {
    instance_id = aws_instance.web.id
    ip          = aws_instance.web.public_ip
    log         = "${path.module}/audit.log"
  }

  provisioner "local-exec" {
    interpreter = ["bash", "-c"]
    command     = "echo \"$(date -u +%FT%TZ) CREATED ${self.input.instance_id} (${self.input.ip})\" >> ${self.input.log}"
  }

  provisioner "local-exec" {
    when        = destroy
    interpreter = ["bash", "-c"]
    command     = "echo \"$(date -u +%FT%TZ) DESTROYED ${self.input.instance_id}\" >> ${self.input.log}"
  }
}

# =============================================================================
# 3. ✅ A file as a RESOURCE (e.g. an Ansible inventory)
#    ❌ Anti-pattern: provisioner "local-exec" { command = "echo ... > inventory.ini" }
#       (no diff, no update when the IP changes, no cleanup on destroy)
# =============================================================================
resource "local_file" "inventory" {
  filename        = "${path.module}/inventory.ini"
  file_permission = "0644"

  content = <<-EOT
    [web]
    ${aws_instance.web.public_ip} ansible_user=ec2-user instance_id=${aws_instance.web.id}
  EOT
}
