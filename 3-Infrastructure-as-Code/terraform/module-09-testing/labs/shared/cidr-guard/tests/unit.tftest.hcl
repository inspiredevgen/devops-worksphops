# =============================================================================
# Unit tests for cidr-guard — run: terraform test
# Tests unitaires de cidr-guard — lancer : terraform test
# EN: No provider, no credentials, no cost. Each "run" is one isolated test case.
# FR : Aucun provider, aucun identifiant, aucun coût. Chaque « run » est un cas de test isolé.
# =============================================================================

# EN: Defaults for every run (a run can override them).
# FR : Valeurs par défaut pour chaque run (un run peut les remplacer).
variables {
  networks = {
    primary   = "10.82.0.0/16"
    secondary = "10.83.0.0/16"
  }
}

run "separate_networks_pass" {
  command = plan

  assert {
    condition     = length(output.overlaps) == 0
    error_message = "Disjoint /16s must not be reported as overlapping."
  }
}

run "contained_network_is_detected" {
  command = plan

  variables {
    networks = {
      big   = "10.0.0.0/8"
      small = "10.83.0.0/16"
      other = "192.168.0.0/24"
    }
  }

  # EN: The output precondition fails, which is exactly what we expect.
  # FR : La précondition de sortie échoue, et c'est exactement ce que l'on attend.
  expect_failures = [output.networks]
}

run "adjacent_networks_do_not_overlap" {
  command = plan

  variables {
    networks = {
      a = "192.168.0.0/24"
      b = "192.168.1.0/24"
    }
  }

  assert {
    condition     = output.overlaps == []
    error_message = "Adjacent /24s share no address."
  }
}

run "invalid_cidr_is_rejected" {
  command = plan

  variables {
    networks = {
      a = "10.0.0.0/16"
      b = "not-a-cidr"
    }
  }

  expect_failures = [var.networks]
}

run "single_network_is_rejected" {
  command = plan

  variables {
    networks = { only = "10.0.0.0/16" }
  }

  expect_failures = [var.networks]
}

# EN: Same overlap, but the bigger network sorts SECOND. A naive comparison would miss it.
#     (This test was added after a mutation test showed the suite missed this bug.)
# FR : Même chevauchement, mais le grand réseau est trié en SECOND. Une comparaison naïve le raterait.
#     (Ce test a été ajouté après qu'un test de mutation a montré que la suite ratait ce bogue.)
run "order_does_not_matter" {
  command = plan

  variables {
    networks = {
      a_small = "10.83.0.0/16"
      b_big   = "10.0.0.0/8"
    }
  }

  expect_failures = [output.networks]
}
