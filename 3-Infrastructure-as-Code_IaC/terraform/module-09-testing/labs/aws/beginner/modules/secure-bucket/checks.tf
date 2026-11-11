# EN: Layer 4: a check block. It runs at every plan and apply and reports a WARNING,
#     but never blocks. Ideal for facts outside this module's control.
# FR : Couche 4 : un bloc check. Il s'exécute à chaque plan et apply et signale un AVERTISSEMENT,
#     sans jamais bloquer. Idéal pour des faits hors du contrôle de ce module.
check "account_blocks_public_access" {
  data "aws_s3_account_public_access_block" "account" {}

  assert {
    condition = alltrue([
      data.aws_s3_account_public_access_block.account.block_public_acls,
      data.aws_s3_account_public_access_block.account.block_public_policy,
      data.aws_s3_account_public_access_block.account.ignore_public_acls,
      data.aws_s3_account_public_access_block.account.restrict_public_buckets,
    ])
    error_message = "EN: Account-level S3 Block Public Access is not fully enabled. / FR : Le blocage de l'accès public S3 au niveau du compte n'est pas entièrement activé."
  }
}
