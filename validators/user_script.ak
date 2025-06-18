// This module defines a validator that manages user-specific script addresses for holding
// Asset Tokens.

use aiken/collection/dict
use cardano/address.{Script}
use cardano/assets.{PolicyId}
use cardano/transaction.{OutputReference, Transaction, find_input}
use functions/utils

/// This validator manages a user-specific script address for holding Asset Tokens.
/// The address is unique to each user, derived from their stake credentials.
/// This design ensures that Asset Tokens are locked in a user-specific contract and cannot be transferred,
/// while allowing the user to spend their Credit Tokens.
validator user_script(asset_policy_id: PolicyId, credit_policy_id: PolicyId) {
  spend(_datum, redeemer: Int, oref: OutputReference, tx: Transaction) {
    let Transaction { inputs, mint, .. } = tx
    expect Some(self_input) = find_input(inputs, oref)
    expect Script(script) = self_input.output.address.payment_credential
    let user_script_address = utils.get_output_addr(script, inputs)
    when redeemer is {
      // Action 0: Reconcile assets by burning Asset and Credit Tokens.
      0 -> {
        expect [Pair(asset_tkn, asset_qty)] =
          mint |> assets.tokens(asset_policy_id) |> dict.to_pairs
        expect [Pair(credit_tkn, credit_qty)] =
          mint |> assets.tokens(credit_policy_id) |> dict.to_pairs

        and {
          // Ensure the quantity of Asset Tokens being burned is negative.
          (asset_qty < 0)?,
          // The quantity of burned Asset Tokens must equal the quantity of burned Credit Tokens.
          (asset_qty == credit_qty)?,
          // Ensure any remaining tokens are sent back to the user's script address.
          utils.must_send_remaining_token_to_addr(
            tx,
            asset_policy_id,
            credit_policy_id,
            asset_tkn,
            credit_tkn,
            credit_qty,
            user_script_address,
          )?,
        }
      }
      // Action 1: Withdraw Credit Tokens or other tokens.
      // This action allows the user to spend tokens from the script address
      1 -> fail @"not yet implemented"
      _ -> fail @"invalid redeemer value"
    }
  }

  else(_) {
    fail
  }
}
