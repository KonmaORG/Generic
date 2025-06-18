// This module implements a comprehensive crowdfunding validator.

use aiken/collection/list
use cardano/address.{Address, Script}
use cardano/addresses
use cardano/assets.{PolicyId}
use cardano/transaction.{
  InlineDatum, Input, Output, OutputReference, Transaction,
}
use cardano/tx
use cardano/value
use constants
use functions/utils
use types/datum.{
  BackerDatum, CampaignDatum, Cancelled, ConfigDatum, Finished, Initiated,
  Running,
}
use types/moment.{Moment}
use types/redeemer.{CampaignAction, Cancel, Finish, Refund, Release, Support}
use types/token.{Token}
use validation/find
use validation/payout

/// The `crowdfunding` validator manages the entire lifecycle of a crowdfunding campaign.
/// It ensures that each campaign has a unique address by combining the script hash with the creator's stake credentials.
/// Key features include:
/// - Milestone-based payment releases, authorized by a multi-signature group.
/// - Fractional, fixed-amount contributions from supporters.
/// - Reward token distribution to backers.
validator crowdfunding(config_nft: PolicyId) {
  // This minting policy controls the campaign's reward tokens.
  // It handles the initial minting of reward tokens when a campaign is created,
  // and the burning of these tokens when a campaign is finished or cancelled.
  mint(
    redeemer campaign_datum: CampaignDatum,
    policy_id self_script: PolicyId,
    tx: Transaction,
  ) {
    when campaign_datum.state is {
      // If the campaign is finished or cancelled, all remaining reward tokens must be burned.
      Finished |
      Cancelled ->
        assets.quantity_of(tx.mint, self_script, campaign_datum.name) <= 0
      // For any other state, it's assumed to be the campaign's initiation.
      _ -> {
        expect CampaignDatum {
          goal,
          name,
          deadline,
          milestone,
          creator,
          fraction,
          state: Initiated,
        } = campaign_datum
        expect goal > 0
        let script_addr = addresses.create_address(self_script, creator.sc)
        let payout_value =
          value.from_token(Token { pid: self_script, tkn: name, amt: fraction })
        and {
          // The campaign deadline must be in the future.
          moment.is_before(
            Moment { start: 0, end: deadline },
            tx.validity_range,
          ),
          // All milestone completion flags must initially be set to `False`.
          !list.has(milestone, True),
          // The number of minted reward tokens must match the campaign's defined fraction.
          assets.quantity_of(tx.mint, self_script, name) == fraction,
          // The newly minted reward tokens must be sent to the unique campaign address.
          payout.exact(script_addr, payout_value, tx.outputs),
        }
      }
    }
  }

  spend(
    datum: Option<Data>,
    redeemer: CampaignAction,
    o_ref: OutputReference,
    tx: Transaction,
  ) {
    expect Some(Input { output: Output { address: script_address, .. }, .. }) =
      transaction.find_input(tx.inputs, o_ref)
    expect Script(self_script) = script_address.payment_credential
    let ConfigDatum { multisig_validator_group, .. } =
      utils.ref_datum_by_nft(
        tx.reference_inputs,
        config_nft,
        constants.identification_tkn,
      )
    // matching based on the datum and redeemer
    when (datum, redeemer) is {
      // Action: Support the campaign.
      // A backer sends funds and receives reward tokens in return.
      // This action is only valid when the campaign is in the 'Running' state.
      (Some(current_datum), Support) ->
        if current_datum is campaign_datum: CampaignDatum {
          let CampaignDatum { name, goal, fraction, creator, .. } =
            campaign_datum
          let fraction_amount = goal / fraction
          // Find the outputs containing the reward tokens: one for the backer, one back to the script.
          expect [backer_reward_output,
            script_reward_output] =
            utils.outputs_by_pid(tx.outputs, self_script, name)
          // Find the outputs sent to the campaign address: one with the backer's funds, one with the remaining reward tokens.
          expect [backer_amount_output,
            script_token_output] =
            utils.outputs_by_addr(
              tx.outputs,
              addresses.create_address(self_script, creator.sc),
            )
          let backer_reward_qty =
            assets.quantity_of(backer_reward_output.value, self_script, name)
          let script_reward_qty =
            assets.quantity_of(script_reward_output.value, self_script, name)

          let backer_lovelace_qty =
            assets.lovelace_of(backer_amount_output.value)
          let script_reward_qty_ =
            assets.quantity_of(script_token_output.value, self_script, name)
          expect InlineDatum(output_datum) = script_token_output.datum
          and {
            // The campaign datum must remain unchanged.
            output_datum == current_datum,
            // The campaign must be in the 'Running' state.
            utils.campaign_state(campaign_datum, Running),
            // The quantity of reward tokens returned to the script must be correct.
            script_reward_qty == script_reward_qty_,
            // The number of reward tokens sent to the backer must correspond to their contribution amount.
            backer_lovelace_qty / fraction_amount == backer_reward_qty,
          }
        } else {
          fail @"Invalid Support Datum Type! Must be CampaignDatum"
        }
      // Action: Cancel the campaign.
      // This can be triggered by the creator at any time or by the platform (multisig) after the deadline.
      // It transitions the campaign state to 'Cancelled' and allows backers to claim refunds.
      (Some(current_datum), Cancel) ->
        if current_datum is campaign_datum: CampaignDatum {
          let CampaignDatum { creator, deadline, .. } = campaign_datum
          let is_signed_by_platform =
            tx.verify_multisig(
              tx.extra_signatories,
              multisig_validator_group.signers,
              multisig_validator_group.required,
            )
          let output_datum_data =
            find.output_datum_by_addr(
              tx.outputs,
              addresses.create_address(self_script, creator.sc),
            )
          let expected_datum_data: Data =
            CampaignDatum { ..campaign_datum, state: Cancelled }
          and {
            // Authorization check: either the platform cancels after the deadline, or the creator cancels anytime.
            if is_signed_by_platform? {
              moment.is_after(
                Moment { start: 0, end: deadline },
                tx.validity_range,
              )
            } else {
              list.has(tx.extra_signatories, creator.pkh)
            },
            // The campaign must be in the 'Running' state to be cancelled.
            utils.campaign_state(campaign_datum, Running),
            // The output datum must correctly reflect the new 'Cancelled' state.
            output_datum_data == expected_datum_data,
          }
        } else if current_datum is backer_datum: BackerDatum {
          // This part handles the refund logic for a supporter when the campaign is cancelled.
          let output_datum_data =
            find.output_datum_by_addr(tx.outputs, script_address)
          expect campaign_datum: CampaignDatum = output_datum_data
          and {
            // The campaign state must be 'Cancelled' to process refunds.
            utils.campaign_state(campaign_datum, Cancelled),
            // The backer must receive the correct refund amount.
            utils.must_refund(tx, script_address, backer_datum)?,
            // The backer's reward tokens must be burned.
            assets.quantity_of(tx.mint, self_script, campaign_datum.name) <= 0,
          }
        } else {
          fail @"Invalid Cancel Datum Type! Must be CampaignDatum or BackerDatum"
        }

      // Action: Finish the campaign.
      // This can be triggered by the creator or the platform when the campaign goal is met.
      // It transitions the state to 'Finished' and consolidates all funds.
      (Some(current_datum), Finish) ->
        if current_datum is campaign_datum: CampaignDatum {
          let is_signed_by_platform =
            tx.verify_multisig(
              tx.extra_signatories,
              multisig_validator_group.signers,
              multisig_validator_group.required,
            )
          let output_datum_data =
            find.output_datum_by_addr(tx.outputs, script_address)
          let expected_datum_data: Data =
            CampaignDatum { ..campaign_datum, state: Finished }
          and {
            // Authorization: can be finished by the platform after the deadline or by the creator anytime.
            if is_signed_by_platform? {
              moment.is_after(
                Moment { start: 0, end: campaign_datum.deadline },
                tx.validity_range,
              )
            } else {
              list.has(tx.extra_signatories, campaign_datum.creator.pkh)
            },
            // The campaign must be in the 'Running' state to be finished.
            utils.campaign_state(campaign_datum, Running),
            // The output datum must reflect the new 'Finished' state.
            output_datum_data == expected_datum_data,
            // All contributed funds must be consolidated into a single UTxO at the script address.
            utils.must_pay_to_script(
              tx,
              script_address,
              campaign_datum: CampaignDatum {
                ..campaign_datum,
                state: Finished,
              },
            ),
            // Any remaining reward tokens must be burned.
            assets.quantity_of(tx.mint, self_script, campaign_datum.name) <= 0,
          }
        } else if current_datum is BackerDatum {
          // This ensures that backers' UTxOs can be consumed during the 'Finish' action.
          let output_datum_data =
            find.output_datum_by_addr(tx.outputs, script_address)
          expect campaign_datum: CampaignDatum = output_datum_data
          utils.campaign_state(campaign_datum, Running)
        } else {
          fail @"Invalid Finish Datum Type!"
        }
      // Action: Refund a backer.
      // This allows a backer to get their funds back if the campaign has been cancelled.
      (Some(current_datum), Refund) ->
        if current_datum is backer_datum: BackerDatum {
          let output_datum_data =
            find.output_datum_by_addr(tx.outputs, script_address)
          expect campaign_datum: CampaignDatum = output_datum_data
          and {
            // The campaign must be in the 'Cancelled' state.
            utils.campaign_state(campaign_datum, Cancelled),
            // The backer must receive their exact contribution back.
            utils.must_refund(tx, script_address, backer_datum)?,
            // The corresponding reward tokens must be burned.
            assets.quantity_of(tx.mint, self_script, campaign_datum.name) <= 0,
          }
        } else {
          fail @"Invalid Refund Datum Type! Must be BackerDatum"
        }
      // Action: Release funds to the creator.
      // This is triggered after the campaign is 'Finished' and allows the creator to withdraw
      // funds based on pre-defined milestones, requiring multisig approval.
      (Some(current_datum), Release) ->
        if current_datum is campaign_datum: CampaignDatum {
          let updated_datum = utils.updating_datum_milestone(campaign_datum)
          let expected_datum_data: Data = updated_datum
          let output_datum_data =
            find.output_datum_by_addr(tx.outputs, script_address)
          and {
            // The transaction must be signed by the multisig group.
            tx.verify_multisig(
              tx.extra_signatories,
              multisig_validator_group.signers,
              multisig_validator_group.required,
            )?,
            // The campaign must be in the 'Finished' state.
            utils.campaign_state(campaign_datum, Finished)?,
            // The output datum must reflect the updated milestone status.
            output_datum_data == expected_datum_data,
            // The funds must be sent to the creator, and the goal must have been met.
            utils.must_reach_goal_and_send_to_creator(
              tx,
              script_address,
              campaign_datum,
            )?,
          }
        } else {
          fail @"Invalid Release Datum Type! Must be CampaignDatum"
        }
      // NoDatum etc:
      _ ->
        tx.verify_multisig(
          tx.extra_signatories,
          multisig_validator_group.signers,
          multisig_validator_group.required,
        )
    }
  }

  else(_) {
    fail
  }
}
