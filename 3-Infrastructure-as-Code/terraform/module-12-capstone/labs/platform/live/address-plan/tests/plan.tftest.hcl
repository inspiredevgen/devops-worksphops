# EN: The real plan must be overlap-free; a bad addition must be caught.
# FR : Le vrai plan doit être sans chevauchement ; un mauvais ajout doit être détecté.

run "the_estate_has_no_overlaps" {
  command = plan

  assert {
    condition     = length(module.guard.overlaps) == 0
    error_message = "The capstone networks overlap."
  }
}

run "a_new_network_inside_prod_is_rejected" {
  command = plan

  variables {
    networks = {
      aws-prod = "10.111.0.0/16"
      new-team = "10.111.64.0/18"
    }
  }

  expect_failures = [output.networks]
}
