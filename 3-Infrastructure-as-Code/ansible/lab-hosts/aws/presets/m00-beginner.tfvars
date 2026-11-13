# Lab 0.B-AWS — one Ubuntu host over SSH / un hôte Ubuntu en SSH
module_tag = "00-setup"
access     = "ssh"
hosts = {
  web1 = { os = "ubuntu", role = "web", environment = "dev" }
}
