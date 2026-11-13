# -----------------------------------------------------------------------------
# EN: v2.0.0 — the internal resource was renamed (aws_vpc.this → aws_vpc.main).
#     Without this block, EVERY caller upgrading to v2 would see their VPC —
#     and everything in it — destroyed and recreated. Module authors MUST ship
#     `moved` blocks for internal refactors. Inside a module, addresses are
#     relative to the module; Terraform maps them to module.<call>.aws_vpc.…
# FR: v2.0.0 — la ressource interne a été renommée (aws_vpc.this → aws_vpc.main).
#     Sans ce bloc, CHAQUE appelant passant à la v2 verrait son VPC — et tout
#     ce qu'il contient — détruit puis recréé. Les auteurs de modules DOIVENT
#     livrer des blocs `moved` pour leurs restructurations internes. Dans un
#     module, les adresses sont relatives ; Terraform les associe à
#     module.<appel>.aws_vpc.…
# -----------------------------------------------------------------------------
moved {
  from = aws_vpc.this
  to   = aws_vpc.main
}
