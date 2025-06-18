// This validator manages the lifecycle of the Identification NFT, a singleton token
// used to uniquely identify the UTxO that holds the protocol's main configuration datum.
// The policy ID of this NFT is passed as a parameter to most other contracts,
// allowing them to easily locate and reference the configuration.

use cardano/assets.{PolicyId}
use cardano/minting
use cardano/transaction.{OutputReference, Transaction}
use cardano/tx as logical_tx
use constants
use types/redeemer.{Action, Burn, Mint}

/// The `identification_nft` validator is a minting policy that controls the creation and
/// destruction of the unique Identification NFT.
/// It takes the `OutputReference` of the transaction output that will be consumed to mint the NFT,
/// ensuring that the minting is a one-time event.
validator identification_nft(o_ref: OutputReference) {
  mint(redeemer: Action, policy_id: PolicyId, tx: Transaction) {
    let Transaction { inputs, mint, .. } = tx
    let flatten_value = assets.flatten(mint)
    when redeemer is {
      // The Mint action is used to create the Identification NFT.
      // It enforces that exactly one token is minted and that the specific UTxO
      // defined by `o_ref` is being spent in the transaction. This ensures
      // that the NFT is a singleton.
      Mint -> and {
          logical_tx.is_spending_input(inputs, o_ref)?,
          minting.exact(
            flatten_value,
            policy_id,
            constants.identification_tkn,
            1,
          )?,
        }

      // The Burn action is used to destroy the Identification NFT.
      // It ensures that exactly one token is burned.
      Burn ->
        minting.exact(
          flatten_value,
          policy_id,
          constants.identification_tkn,
          -1,
        )
    }
  }

  else(_) {
    fail
  }
}
