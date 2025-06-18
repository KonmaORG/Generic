use aiken/collection/list
use cardano/addresses
use cardano/transaction.{OutputReference, Transaction}
use constants
use functions/utils
use types/datum.{MarketplaceDatum}
use types/redeemer.{Buy, MarketplaceRedeemer, Withdraw}
use validation/payout

/// The `marketplace` validator implements a simple marketplace for assets.
/// It allows owners to list Credit Tokens for sale and buyers to purchase them.
/// The validator also enforces a royalty fee on each sale.
validator marketplace {
  spend(
    datum: Option<MarketplaceDatum>,
    redeemer: MarketplaceRedeemer,
    _oref: OutputReference,
    tx: Transaction,
  ) {
    let Transaction { outputs, extra_signatories, .. } = tx
    expect Some(MarketplaceDatum { owner: seller, amount }) = datum
    let (marketplace_payout, seller_payout) =
      utils.calculate_payout_royalty(amount)
    when redeemer is {
      // The Buy action allows a user to purchase the asset locked at the contract.
      // It ensures that the seller receives the correct payout and that the
      // marketplace royalty is paid to the designated address.
      Buy -> and {
          payout.at_least(addresses.from_wallet(seller), seller_payout, outputs)?,
          payout.at_least(
            addresses.from_wallet(constants.royalty_addr),
            marketplace_payout,
            outputs,
          )?,
        }
      // The Withdraw action allows the original owner of the asset to withdraw it
      // from the marketplace without a sale.
      // It requires the transaction to be signed by the owner.
      Withdraw -> list.has(extra_signatories, seller.pkh)
    }
  }

  else(_) {
    fail
  }
}
