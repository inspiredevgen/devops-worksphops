# -----------------------------------------------------------------------------
# EN: v2.0.0 — internal rename azurerm_virtual_network.this → .main.
#     Without this block, every caller upgrading would see the VNet and ALL its
#     subnets destroyed and recreated. Module authors MUST ship `moved` blocks.
# FR: v2.0.0 — renommage interne azurerm_virtual_network.this → .main.
#     Sans ce bloc, chaque appelant verrait le VNet et TOUS ses sous-réseaux
#     détruits puis recréés. Les auteurs de modules DOIVENT livrer des blocs `moved`.
# -----------------------------------------------------------------------------
moved {
  from = azurerm_virtual_network.this
  to   = azurerm_virtual_network.main
}
