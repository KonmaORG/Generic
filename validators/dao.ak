//// DAO Proposal Management Validator
//// This validator manages the lifecycle of DAO proposals, including voting and execution.
//// It ensures that proposals can only be voted on when they are in progress, and that
//// they can only be executed after the voting period has ended and the proposal has been approved.
//// It also handles the rejection of proposals that fail to meet the necessary criteria.

use aiken/collection/list
use cardano/address.{Script}
use cardano/assets.{PolicyId}
use cardano/transaction.{
  InlineDatum, OutputReference, Transaction, find_input, find_script_outputs,
}
use constants
use functions/utils
use types/datum.{ConfigDatum, GovernanceDatum}
use types/moment
use types/redeemer.{
  ExecuteProposal, GovernanceRedeemer, RejectProposal, SubmitProposal,
  VoteProposal,
}
use types/utils.{
  Abstain, Executed, FeeAmountUpdate, InProgress, No, Pending, Rejected, Yes,
} as types

/// A validator for managing DAO proposals.
/// This script controls the lifecycle of a proposal, including voting and resolution.
///
/// # Parameters
/// * `config_nft` - The PolicyId of the configuration NFT. Note: This is not currently used in the spend validator.
validator dao(config_nft: PolicyId) {
  /// The `spend` validator logic is triggered when a UTxO locked by this script is spent.
  /// It handles actions like voting on proposals and rejecting failed proposals.
  spend(
    datum: Option<Data>,
    redeemer: GovernanceRedeemer,
    oref: OutputReference,
    tx: Transaction,
  ) {
    when datum is {
      Some(data) -> {
        let datum = utils.governance_datum_from_data(data)
        // The script requires that the proposal UTxO be spent and a new one created
        // in the same transaction, carrying forward the updated state.
        // Find the script's own hash to locate the continuing output.
        let self_hash = {
          expect Some(input) = find_input(tx.inputs, oref)
          expect Script(script_hash) = input.output.address.payment_credential
          script_hash
        }

        // Expect exactly one output to be sent back to the script address.
        let self_output = {
          expect [output] = find_script_outputs(tx.outputs, self_hash)
          output
        }

        // Decode the datum from the continuing output.
        let self_output_datum = {
          expect InlineDatum(data) = self_output.datum
          utils.governance_datum_from_data(data)
        }

        // Handle actions based on the provided redeemer.
        when redeemer is {
          // Proposal submission is not handled by this spend validator.
          // It's handled by a minting policy that creates the initial proposal UTxO.
          SubmitProposal { .. } ->
            fail @"Invalid Redeemer: Proposal submission not allowed"
          // 1. The proposal ID must remain unchanged.
          // 2. The proposal must be in the 'InProgress' state to allow voting.
          // 3. The vote must be cast before the proposal's deadline.
          // 5. The voter must not have already voted (their status must be 'Pending').
          // 6. The output datum must correctly reflect the new vote cast by the voter.
          // 7. The proposal state must remain 'InProgress' after the vote.
          // 8. The relevant vote count must be incremented by exactly one.
          // TODO: check if the voter has signed the tx
          VoteProposal { proposal_id, voter, vote } -> and {
              (proposal_id == self_output_datum.proposal_id)?,
              (datum.proposal_id == self_output_datum.proposal_id)?,
              (datum.proposal_state == InProgress)?,
              moment.is_contained(datum.deadline, tx.validity_range)?,
              (Pending == utils.get_vote(datum.votes, voter))?,
              (vote == utils.get_vote(self_output_datum.votes, voter))?,
              (self_output_datum.proposal_state == InProgress)?,
              when vote is {
                Yes ->
                  (datum.votes_count.yes + 1 == self_output_datum.votes_count.yes)?
                No ->
                  (datum.votes_count.no + 1 == self_output_datum.votes_count.no)?
                Abstain ->
                  (datum.votes_count.abstain + 1 == self_output_datum.votes_count.abstain)?
                _ -> fail @"Invalid Vote type"
              },
            }

          // Proposal execution is not yet implemented.
          // finds configDatum using config_nft
          // finds the output_configDatum using config_nft
          // match's the configDatum and the output_configDatum
          // the match is done based on the ProposalAction. if its `feesupdate` then we update configDatum's fees field and compare it to the output_configDatum
          ExecuteProposal { proposal_id } -> {
            trace @"started Execute..........."
            expect and {
                // 1. The proposal ID must match.
                // 2. The proposal must currently be 'InProgress'.
                // 3. The transaction must be after the voting deadline.
                // 4. The number of 'Yes' votes must be strictly greater than 'No' votes.
                // 5. The final state of the proposal in the output datum must be 'Executed'.
                (proposal_id == datum.proposal_id)?,
                (datum.proposal_state == InProgress)?,
                moment.is_after(datum.deadline, tx.validity_range)?,
                (datum.votes_count.yes > datum.votes_count.no)?,
                (self_output_datum.proposal_state == Executed)?,
              }
            trace @"passed and block --------------------"
            let current_config_datum =
              utils.ref_datum_by_nft(
                tx.inputs,
                config_nft,
                constants.identification_tkn,
              )
            trace @"found config datm **************"
            let new_config_datum =
              utils.output_ref_datum_by_nft(
                tx.outputs,
                config_nft,
                constants.identification_tkn,
              )
            trace @"found updated config datum"
            when self_output_datum.proposal_action is {
              FeeAmountUpdate(updated_fee) ->
                ConfigDatum { ..current_config_datum, fees_amount: updated_fee } == new_config_datum
              _ -> fail @"Invalid Action"
            }
          }

          // 1. The proposal ID must match.
          // 2. The proposal must currently be 'InProgress'.
          // 3. The transaction must be after the voting deadline.
          // 4. The number of 'No' votes must be strictly greater than 'Yes' votes.
          // 5. The final state of the proposal in the output datum must be 'Rejected'.
          RejectProposal { proposal_id } -> and {
              (proposal_id == self_output_datum.proposal_id)?,
              (datum.proposal_id == self_output_datum.proposal_id)?,
              (datum.proposal_state == InProgress)?,
              moment.is_after(datum.deadline, tx.validity_range)?,
              (datum.votes_count.no > datum.votes_count.yes)?,
              (self_output_datum.proposal_state == Rejected)?,
            }
        }
      }
      None -> fail @"Datum is required"
    }
  }

  mint(redeemer: GovernanceRedeemer, policy_id: PolicyId, tx: Transaction) {
    when redeemer is {
      SubmitProposal { proposal_id } -> {
        // output datum must be a GovernanceDatum
        // must be signedby the submitted_by
        // output datum proposal_id must match the proposal_id from redeemer
        // output datum proposal_state must be InProgress
        // output must be going to a script address
        let output = utils.output_by_nft(tx.outputs, policy_id, proposal_id)
        let datum = {
          expect InlineDatum(data) = output.datum
          utils.governance_datum_from_data(data)
        }
        // TODO: configDatum.daoMember must match the datum.votes list.
        // TODO: votes_count must be 0 for yes, no, abstain
        and {
          list.has(tx.extra_signatories, datum.submitted_by),
          datum.proposal_id == proposal_id,
          datum.proposal_state == InProgress,
          output.address.payment_credential == Script(policy_id),
        }
      }
      _ -> fail @"Invalid Redeemer: only SubmitProposal is allowed in minting"
    }
  }

  else(_) {
    fail @"Invalid transaction type"
  }
}
