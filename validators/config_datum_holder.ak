//// This validator is responsible for safeguarding the central configuration datum of the protocol.
//// It ensures that any modifications to the configuration are authorized by a multi-signature group.

use cardano/assets.{PolicyId}
use cardano/transaction.{InlineDatum, Transaction}
use functions/utils as lib
use types/datum.{ConfigDatum}
use types/utils.{Executed, InProgress}
use validation/find

/// The `config_datum_holder` validator locks the main `ConfigDatum` and the Identification NFT.
/// Spending from this validator requires approval from a specified multi-signature group,
/// preventing unauthorized changes to the protocol's configuration.
/// added config_nft as param to have unique address while testing
validator config_datum_holder(_config_nft: PolicyId) {
  spend(
    datum: Option<ConfigDatum>,
    redeemer proposal_id: ByteArray,
    _oref,
    tx: Transaction,
  ) {
    // This validator ensures that any changes to the configuration are made
    // only after a corresponding proposal has been approved and executed in the DAO.
    //
    // It performs the following checks:
    // 1. Finds the DAO validator's input and output in the transaction using an NFT
    //    uniquely associated with the proposal (`proposal_id`). The policy ID of this
    //    NFT is stored in the `ConfigDatum`.
    // 2. Extracts the `GovernanceDatum` from both the DAO's input and output.
    // 3. Verifies that the proposal's state transitions from `InProgress` to `Executed`,
    //    confirming that the proposal has been successfully approved and is now being
    //    implemented.
    when datum is {
      Some(datum) -> {
        trace @"-----------------\n dao Policy": datum.dao_policyid, proposal_id
        let dao_input =
          find.input_by_nft(tx.inputs, datum.dao_policyid, proposal_id)
        trace @"dao input found"
        let dao_output =
          lib.output_by_nft(tx.outputs, datum.dao_policyid, proposal_id)
        let input_governance_datum = {
          expect InlineDatum(data) = dao_input.output.datum
          lib.governance_datum_from_data(data)
        }
        let output_governance_datum = {
          expect InlineDatum(data) = dao_output.datum
          lib.governance_datum_from_data(data)
        }
        and {
          input_governance_datum.proposal_state == InProgress,
          output_governance_datum.proposal_state == Executed,
        }
      }
      _ -> fail @"Invalid datum: Expected ConfigDatum, got None."
    }
  }

  else(_) {
    fail
  }
}
