# Lab 0.B-AZ — one Ubuntu VM over SSH / une VM Ubuntu en SSH
module_tag = "00-setup"
access     = "ssh"
hosts = {
  web1 = { os = "ubuntu", role = "web", environment = "dev" }
}
