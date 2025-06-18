//// This module handles the burning and minting of the `Asset Token`

use aiken/collection/dict
use cardano/assets.{PolicyId}
use cardano/transaction.{InlineDatum, Transaction}
use functions/utils
use types/datum.{AssetDatum}
use types/redeemer.{AssetBurnRedeemer}

/// The `asset_minter` validator handles the minting and burning of Asset Tokens.
/// It ensures that Asset Tokens are minted correctly based on asset data and can be burned
/// in a 1:1 ratio with Credit Tokens.
validator asset_minter {
  mint(redeemer: Data, policy_id: PolicyId, tx: Transaction) {
    let Transaction { mint, inputs, outputs, .. } = tx

    // The validator's behavior depends on the type of redeemer provided.
    if redeemer is AssetDatum {
      // This branch handles the minting of new Asset Tokens.
      let AssetDatum { asset_qty, .. } = redeemer
      // Ensure that tokens are being minted under the correct policy.
      expect [Pair(token_name, qty)] =
        mint |> assets.tokens(policy_id) |> dict.to_pairs
      let asset_output = utils.user_script_address(inputs, outputs)
      expect InlineDatum(datum_data) = asset_output.datum
      let redeemer_data: Data = redeemer
      and {
        // The minted quantity must match the quantity specified in the redeemer.
        qty == asset_qty,
        // The same quantity of Asset Tokens must be sent to the user script address.
        assets.quantity_of(asset_output.value, policy_id, token_name) == qty,
        // The datum in the output must match the redeemer.
        datum_data == redeemer_data,
      }
    } else if redeemer is AssetBurnRedeemer {
      // This branch handles the burning of Asset Tokens.
      expect [Pair(_, asset_qty)] =
        mint |> assets.tokens(policy_id) |> dict.to_pairs
      expect [Pair(_, credit_qty)] =
        mint |> assets.tokens(redeemer.credit_policy_id) |> dict.to_pairs
      and {
        // The quantity of Asset Tokens being burned must be negative.
        asset_qty < 0,
        // The quantity of burned Asset Tokens must equal the quantity of burned Credit Tokens.
        asset_qty == credit_qty,
      }
    } else {
      fail @"invalid redeemer"
    }
  }

  else(_) {
    fail
  }
}
