//// This module contains two validators: 'initiator' for initiating projects
//// and 'validator' for validating them.

use aiken/collection/dict
use cardano/address.{Script}
use cardano/addresses
use cardano/assets.{PolicyId}
use cardano/transaction.{
  InlineDatum, Output, OutputReference, Transaction, find_input,
}
use cardano/tx
use cardano/value
use constants
use functions/utils
use types/datum.{ProjectDatum}
use types/redeemer.{ProjectValidationRedeemer}
use types/token.{Token}
use validation/find
use validation/payout

/// The `project_validation` validator manages the approval or rejection of projects.
/// It enforces a multi-signature scheme where a group of validators must sign the transaction.
/// This validator is also responsible for minting Credit Tokens.
validator project_validation(
  config_nft: PolicyId,
  validator_contract_mint: PolicyId,
) {
  /// This function handles the spending of the UTxO locked at the validator address.
  /// It ensures that the transaction is signed by the required number of multi-signature
  /// validators defined in the configuration datum.
  spend(
    datum: Option<ProjectDatum>,
    redeemer: ProjectValidationRedeemer,
    oref: OutputReference,
    tx: Transaction,
  ) {
    expect Some(datum) = datum
    let Transaction {
      mint,
      inputs,
      reference_inputs,
      extra_signatories,
      outputs,
      ..
    } = tx
    expect Some(script_input) = find_input(inputs, oref)
    expect Script(script_hash) = script_input.output.address.payment_credential
    let ref_datum =
      utils.ref_datum_by_nft(
        reference_inputs,
        config_nft,
        constants.identification_tkn,
      )

    // Handle different actions based on the redeemer.
    when redeemer.action is {
      // Action 0: Accept the project.
      // The project initiator receives the minted Credit Tokens.
      // The project's NFT is burned as part of this process.
      0 -> {
        let initiator_addr = addresses.from_wallet(datum.initiator)
        let tkname = utils.token_name_oref(oref)
        let value =
          value.from_token(
            Token { pid: script_hash, tkn: tkname, amt: redeemer.amount },
          )
        and {
          utils.must_burn_less_than_0(mint, validator_contract_mint),
          payout.exact(initiator_addr, value, outputs)?,
        }
      }
      // Action 1: Reject the project.
      // The project's NFT is burned, and the transaction must be signed by the multisig group.
      1 -> and {
          utils.must_burn_less_than_0(mint, validator_contract_mint),
          tx.verify_multisig(
            extra_signatories,
            ref_datum.multisig_validator_group.signers,
            ref_datum.multisig_validator_group.required,
          ),
        }
      _ -> fail
    }
  }

  /// This function handles the minting and burning of tokens.
  /// It's responsible for minting Credit Tokens when a project is approved
  /// and burning Credit Tokens in exchange for Asset Tokens.
  mint(
    redeemer: ProjectValidationRedeemer,
    policy_id: PolicyId,
    tx: Transaction,
  ) {
    let Transaction { inputs, mint, reference_inputs, extra_signatories, .. } =
      tx
    let ref_datum =
      utils.ref_datum_by_nft(
        reference_inputs,
        config_nft,
        constants.identification_tkn,
      )

    when redeemer.action is {
      // Action 0: Mint Credit Tokens for an approved project.
      0 -> {
        expect Some(oref_input) = find_input(inputs, redeemer.oref)
        expect InlineDatum(oref_input_datum) = oref_input.output.datum
        expect _: ProjectDatum = oref_input_datum
        // Generate the token name from the output reference.
        let tkname = utils.token_name_oref(redeemer.oref)
        and {
          utils.must_burn_less_than_0(mint, validator_contract_mint),
          value.prove_exact_nft(mint, policy_id, tkname),
          tx.verify_multisig(
            extra_signatories,
            ref_datum.multisig_validator_group.signers,
            ref_datum.multisig_validator_group.required,
          ),
        }
      }
      // Action 1: Burn Credit Tokens.
      // This can be done either by a multisig approval or by providing an equivalent amount of Asset Tokens to be burned.
      1 -> {
        let multi_sig =
          tx.verify_multisig(
            extra_signatories,
            ref_datum.multisig_validator_group.signers,
            ref_datum.multisig_validator_group.required,
          )
        if multi_sig {
          utils.must_burn_less_than_0(mint, policy_id)
        } else {
          expect [Pair(_, asset_qty)] =
            mint |> assets.tokens(ref_datum.asset_policy_id) |> dict.to_pairs
          expect [Pair(_, credit_qty)] =
            mint |> assets.tokens(policy_id) |> dict.to_pairs
          and {
            asset_qty < 0,
            credit_qty == asset_qty,
          }
        }
      }
      _ -> fail
    }
  }

  else(_) {
    fail
  }
}

/// This validator handles the creation of new projects.
/// It mints a unique project NFT and sends it to the `validator` contract for approval.
validator initiator(config_nft: PolicyId) {
  mint(redeemer: Int, policy_id: PolicyId, tx: Transaction) {
    let Transaction { mint, reference_inputs, outputs, .. } = tx
    when redeemer is {
      // Action 0: Create a new project.
      // This action validates the project's category, ensures the platform fee is paid,
      // mints the project NFT, and sends the NFT and project datum to the
      // `validator` contract.
      0 -> {
        let ref_datum =
          utils.ref_datum_by_nft(
            reference_inputs,
            config_nft,
            constants.identification_tkn,
          )
        // Get the platform fee address from the reference datum.
        let payout_addr = addresses.from_wallet(ref_datum.fees_address)
        // Get the project validation contract address.
        let project_validation_addr =
          addresses.from_wallet(ref_datum.spend_address)
        let project_validation_output =
          find.output_by_addr(outputs, project_validation_addr)
        expect InlineDatum(script_data) = project_validation_output.datum
        expect project_validation_datum: ProjectDatum = script_data
        let payout_value =
          value.from_token(
            Token {
              pid: ref_datum.fees_asset_class.policy_id,
              tkn: ref_datum.fees_asset_class.asset_name,
              amt: ref_datum.fees_amount,
            },
          )
        and {
          utils.is_category_from_supported_categories(
            ref_datum.categories,
            project_validation_datum.category,
          )?,
          value.prove_exact_nft(
            mint,
            policy_id,
            project_validation_datum.asset_name,
          )?,
          payout.exact(payout_addr, payout_value, outputs),
          utils.must_send_nft_and_datum_to_script(
            project_validation_output,
            policy_id,
          )?,
        }
      }
      // Action 1: Burn a project NFT.
      // This allows for the burning of one or more project NFTs at the same time.
      1 -> utils.must_burn_less_than_0(mint, policy_id)

      _ -> fail
    }
  }

  else(_) {
    fail
  }
}
