# -----------------------------------------------------------------------------
# Lab 7.I-AZ — Provisioners, used SAFELY
# Lab 7.I-AZ — Les provisioners, utilisés en TOUTE SÉCURITÉ
#
# EN: Rules applied here:
#     1. Attach provisioners to terraform_data, NOT to the VM: a failure only
#        TAINTS the cheap terraform_data — the VM is not recreated.
#     2. Control re-runs explicitly with triggers_replace.
#     3. Pass values through `environment`, not interpolation into shell code.
#     4. Prefer a RESOURCE (local_file) over a script that writes files.
# FR: Règles appliquées ici :
#     1. Attacher les provisioners à terraform_data, PAS à la VM : un échec ne
#        MARQUE « tainted » que le terraform_data — la VM n'est pas recréée.
#     2. Contrôler les réexécutions explicitement avec triggers_replace.
#     3. Passer les valeurs via `environment`, pas par interpolation dans le shell.
#     4. Préférer une RESSOURCE (local_file) à un script qui écrit des fichiers.
#
#     ⚠️ local-exec runs on YOUR machine: bash required (Windows → Git Bash/WSL).
#     ⚠️ local-exec s'exécute sur VOTRE machine : bash requis (Windows → Git Bash/WSL).
# -----------------------------------------------------------------------------

resource "terraform_data" "smoke_test" {
  triggers_replace = [azurerm_linux_virtual_machine.web.id, var.smoke_test_port]

  provisioner "local-exec" {
    interpreter = ["bash", "-c"]

    environment = {
      URL      = "http://${azurerm_public_ip.web.ip_address}:${var.smoke_test_port}/"
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

resource "terraform_data" "audit" {
  # EN: Destroy-time provisioners may only use `self` → store what they need in input.
  # FR: Les provisioners de destruction ne peuvent utiliser que `self` → stocker le nécessaire dans input.
  input = {
    vm_id = azurerm_linux_virtual_machine.web.id
    ip    = azurerm_public_ip.web.ip_address
    log   = "${path.module}/audit.log"
  }

  provisioner "local-exec" {
    interpreter = ["bash", "-c"]
    command     = "echo \"$(date -u +%FT%TZ) CREATED ${self.input.vm_id} (${self.input.ip})\" >> ${self.input.log}"
  }

  provisioner "local-exec" {
    when        = destroy
    interpreter = ["bash", "-c"]
    command     = "echo \"$(date -u +%FT%TZ) DESTROYED ${self.input.vm_id}\" >> ${self.input.log}"
  }
}

# EN: ✅ A file as a RESOURCE. ❌ Anti-pattern: local-exec "echo ... > inventory.ini".
# FR: ✅ Un fichier comme RESSOURCE. ❌ Anti-patron : local-exec "echo ... > inventory.ini".
resource "local_file" "inventory" {
  filename        = "${path.module}/inventory.ini"
  file_permission = "0644"

  content = <<-EOT
    [web]
    ${azurerm_public_ip.web.ip_address} ansible_user=azureuser vm_id=${azurerm_linux_virtual_machine.web.id}
  EOT
}
