// This validator is responsible for safeguarding the central configuration datum of the protocol.
// It ensures that any modifications to the configuration are authorized by a multi-signature group.

use cardano/transaction.{Transaction}
use cardano/tx
use types/datum.{ConfigDatum}

/// The `config_datum_holder` validator locks the main `ConfigDatum` and the Identification NFT.
/// Spending from this validator requires approval from a specified multi-signature group,
/// preventing unauthorized changes to the protocol's configuration.
validator config_datum_holder {
  spend(datum: Option<ConfigDatum>, _redeemer, _oref, tx: Transaction) {
    expect Some(datum) = datum
    let Transaction { extra_signatories, .. } = tx
    // This spend function enforces that the transaction is signed by the required number of
    // signatories defined in the `multisig_refutxoupdate` field of the `ConfigDatum`.
    // This provides a secure mechanism for updating the protocol's configuration.
    tx.verify_multisig(
      extra_signatories,
      datum.multisig_refutxoupdate.signers,
      datum.multisig_refutxoupdate.required,
    )
  }

  else(_) {
    fail
  }
}
