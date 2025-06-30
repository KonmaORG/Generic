use aiken/cbor
use aiken/collection/dict
use aiken/collection/list
use aiken/crypto
use cardano/address.{Address, Inline, Script, VerificationKey}
use cardano/addresses
use cardano/assets.{AssetName, PolicyId, Value}
use cardano/transaction.{
  InlineDatum, Input, Output, OutputReference, Transaction,
}
use cardano/value
use constants
use types/datum.{
  BackerDatum, CampaignDatum, CampaignState, ConfigDatum, GovernanceDatum,
  Milestone, ProjectDatum,
}
use types/token.{Token}
use types/utils.{AddressTuple, PaymentKeyHash, StakeKeyHash, Vote, Voter, Votes}
use validation/find
use validation/payout

/// Checks if a given project category is present in the list of supported categories.
///
/// # Arguments
/// * `categories` - A list of supported category names.
/// * `category` - The category to check.
///
/// # Returns
/// `True` if the category is supported, `False` otherwise.
pub fn is_category_from_supported_categories(
  categories: List<ByteArray>,
  category: ByteArray,
) -> Bool {
  list.has(categories, category)
}

/// Ensures that a transaction output sent to a script contains a specific NFT and a valid `ProjectDatum`.
///
/// # Arguments
/// * `output` - The transaction output to validate.
/// * `policy_id` - The policy ID of the required NFT.
pub fn must_send_nft_and_datum_to_script(output: Output, policy_id: PolicyId) {
  expect InlineDatum(output_datum) = output.datum
  expect _: ProjectDatum = output_datum
  list.has(output.value |> assets.policies, policy_id)?
}

/// Verifies that all tokens being minted under a specific policy have a negative amount (i.e., are being burned).
///
/// # Arguments
/// * `mint` - The `Value` from the transaction's mint field.
/// * `policy_id` - The policy ID of the tokens to check.
///
/// # Returns
/// `True` if all specified tokens are being burned, otherwise fails.
pub fn must_burn_less_than_0(mint: Value, policy_id: PolicyId) -> Bool {
  let values: Pairs<AssetName, Int> =
    mint
      |> assets.tokens(policy_id)
      |> dict.to_pairs()

  list.all(values, fn(Pair(_, amount)) { amount < 0 })?
}

/// Finds and returns the `ConfigDatum` from a reference input that contains a specific NFT.
///
/// # Arguments
/// * `inputs` - The list of reference inputs from the transaction.
/// * `pid` - The policy ID of the identification NFT.
/// * `tkn` - The asset name of the identification NFT.
///
/// # Returns
/// The `ConfigDatum` found in the reference input. Fails if not found or if the datum type is incorrect.
pub fn ref_datum_by_nft(
  inputs: List<Input>,
  pid: PolicyId,
  tkn: AssetName,
) -> ConfigDatum {
  let datum_data = input_datum_by_nft(inputs, pid, tkn)
  if datum_data is datum: ConfigDatum {
    datum
  } else {
    fail @"Datum Type did not Match ConfigDatum On Input"
  }
}

/// Finds and returns the `ConfigDatum` from a transaction output that contains a specific NFT.
///
/// # Arguments
/// * `outputs` - The list of transaction outputs to search.
/// * `pid` - The policy ID of the identification NFT.
/// * `tkn` - The asset name of the identification NFT.
///
/// # Returns
/// The `ConfigDatum` found in the output. Fails if not found or if the datum type is incorrect.
pub fn output_ref_datum_by_nft(
  outputs: List<Output>,
  pid: PolicyId,
  tkn: AssetName,
) -> ConfigDatum {
  let datum_data = find.output_datum_by_nft(outputs, pid, tkn)
  if datum_data is datum: ConfigDatum {
    datum
  } else {
    fail @"Datum Type did not Match ConfigDatum On Input"
  }
}

/// Validates that a specific token is sent to a script address derived from a given address tuple,
/// and that the output datum matches the address tuple.
///
/// # Arguments
/// * `outputs` - The list of transaction outputs.
/// * `policy_id` - The policy ID of the token.
/// * `token_name` - The asset name of the token.
/// * `redeemer` - The `AddressTuple` containing the payment and stake key hashes.
pub fn script_address_check(
  outputs: List<Output>,
  policy_id: PolicyId,
  token_name: ByteArray,
  redeemer: AddressTuple,
) {
  expect Some(output) =
    list.find(
      outputs,
      fn(o) { assets.quantity_of(o.value, policy_id, token_name) == 1 },
    )
  let address_data: Data = redeemer
  expect InlineDatum(address_datum) = output.datum
  and {
    output.address == script_address_from_tuple(redeemer),
    (address_datum == address_data)?,
  }
}

/// Recursively searches through a list of inputs to find the inline datum of the input
/// that contains a specific NFT.
///
/// # Arguments
/// * `inputs` - The list of inputs to search.
/// * `pid` - The policy ID of the NFT.
/// * `tkn` - The asset name of the NFT.
///
/// # Returns
/// The `Data` from the inline datum of the matching input. Fails if no matching input with a datum is found.
pub fn input_datum_by_nft(
  inputs: List<Input>,
  pid: PolicyId,
  tkn: AssetName,
) -> Data {
  when inputs is {
    [input, ..rest] ->
      if value.prove_exact_nft(input.output.value, pid, tkn) {
        when input.output.datum is {
          InlineDatum(inbound_datum) -> inbound_datum
          _ -> fail @"No Datum On Input"
        }
      } else {
        input_datum_by_nft(rest, pid, tkn)
      }
    [] -> fail @"No Datum Found In inputs"
  }
}

/// Filters a list of outputs, returning only those that contain a specific token.
///
/// # Arguments
/// * `outputs` - The list of outputs to filter.
/// * `pid` - The policy ID of the token.
/// * `tkn` - The asset name of the token.
///
/// # Returns
/// A new list containing only the outputs with the specified token.
pub fn outputs_by_pid(
  outputs: List<Output>,
  pid: PolicyId,
  tkn: ByteArray,
) -> List<Output> {
  let output =
    when outputs is {
      [output, ..rest] ->
        if value.prove_exact_nft(output.value, pid, tkn) {
          [output, ..outputs_by_pid(rest, pid, tkn)]
        } else {
          outputs_by_pid(rest, pid, tkn)
        }
      [] -> []
    }
  output
}

/// Filters a list of outputs, returning only those sent to a specific address.
///
/// # Arguments
/// * `outputs` - The list of outputs to filter.
/// * `addr` - The address to match.
///
/// # Returns
/// A new list containing only the outputs sent to the specified address.
pub fn outputs_by_addr(outputs: List<Output>, addr: Address) -> List<Output> {
  let output =
    when outputs is {
      [output, ..rest] ->
        if output.address == addr {
          [output, ..outputs_by_addr(rest, addr)]
        } else {
          outputs_by_addr(rest, addr)
        }
      [] -> []
    }
  output
}

/// A private helper function to recursively calculate the total amount of Asset and Credit tokens in a list of inputs.
///
/// # Arguments
/// * `inputs` - The list of inputs to process.
/// * `asset_pid` - The policy ID for Asset tokens.
/// * `credit_pid` - The policy ID for Credit tokens.
/// * `asset_tkn` - The asset name for Asset tokens.
/// * `credit_tkn` - The asset name for Credit tokens.
/// * `asset_qty` - The accumulated quantity of Asset tokens.
/// * `credit_qty` - The accumulated quantity of Credit tokens.
///
/// # Returns
/// A tuple containing the total quantities of Asset and Credit tokens.
fn do_total_token_amount(
  inputs: List<Input>,
  asset_pid: PolicyId,
  credit_pid: PolicyId,
  asset_tkn: ByteArray,
  credit_tkn: ByteArray,
  asset_qty: Int,
  credit_qty: Int,
) {
  when inputs is {
    [input, ..rest] -> {
      let asset_amt: Int =
        assets.quantity_of(input.output.value, asset_pid, asset_tkn)
      let credit_amt: Int =
        assets.quantity_of(input.output.value, credit_pid, credit_tkn)
      do_total_token_amount(
        rest,
        asset_pid,
        credit_pid,
        asset_tkn,
        credit_tkn,
        asset_qty + asset_amt,
        credit_qty + credit_amt,
      )
    }
    [] -> (asset_qty, credit_qty)
  }
}

/// Constructs a script address with a delegation part derived from the stake credential of the first input.
///
/// # Arguments
/// * `script` - The policy ID of the script, used as the payment credential.
/// * `inputs` - The list of transaction inputs.
///
/// # Returns
/// A new `Address` with the script as the payment part and the input's stake key as the delegation part.
pub fn get_output_addr(script: PolicyId, inputs: List<Input>) {
  expect Some(input) = list.head(inputs)
  when input.output.address.stake_credential is {
    Some(Inline(VerificationKey(skh))) ->
      address.from_script(script)
        |> address.with_delegation_key(skh)
    _ -> fail @"Input Stake Componenet Missing"
  }
}

/// Generates a unique token name by hashing an `OutputReference`.
///
/// # Arguments
/// * `oref` - The `OutputReference` to hash.
///
/// # Returns
/// A `ByteArray` representing the Blake2b-224 hash of the serialized `OutputReference`.
pub fn token_name_oref(oref: OutputReference) {
  let hashed = oref |> cbor.serialise |> crypto.blake2b_224
  hashed
}

/// Calculates the payout amounts for the seller and the marketplace based on a fixed royalty percentage.
///
/// # Arguments
/// * `amount` - The total sale amount.
///
/// # Returns
/// A tuple containing the `Value` for the marketplace royalty and the `Value` for the seller's payout.
pub fn calculate_payout_royalty(amount: Int) {
  let marketplace = amount * constants.royalty_amt / 100
  let seller = amount - marketplace
  let marketplace_payout =
    value.from_token(Token { pid: "", tkn: "", amt: marketplace })
  let seller_payout = value.from_token(Token { pid: "", tkn: "", amt: seller })
  (marketplace_payout, seller_payout)
}

/// Finds and returns the user script output by matching the stake key of an input with an output.
///
/// # Arguments
/// * `inputs` - The list of transaction inputs.
/// * `outputs` - The list of transaction outputs.
///
/// # Returns
/// The `Output` that is sent to the user's script address. Fails if no matching output is found.
pub fn user_script_address(inputs: List<Input>, outputs: List<Output>) {
  expect Some(input) = list.head(inputs)
  expect Some(Inline(VerificationKey(skh))) =
    input.output.address.stake_credential
  expect Some(output) = list.head(outputs)
  when (output.address.payment_credential, output.address.stake_credential) is {
    (Script(_), Some(Inline(VerificationKey(o_sk)))) ->
      if skh == o_sk {
        output
      } else {
        fail @"Incorrect Stake Component"
      }
    _ -> fail @"Incorrect Tokens Output Address"
  }
}

/// Creates a script address from a tuple of payment and stake key hashes.
///
/// # Arguments
/// * `key_hash_tuple` - A tuple containing the `PaymentKeyHash` and `StakeKeyHash`.
///
/// # Returns
/// A new `Address` with a script payment credential and an optional stake credential.
pub fn script_address_from_tuple(key_hash_tuple: (PaymentKeyHash, StakeKeyHash)) {
  let (pkh, skh) = key_hash_tuple
  Address {
    payment_credential: pkh |> Script,
    stake_credential: if skh == "" {
      None
    } else {
      skh |> Script |> Inline |> Some
    },
  }
}

/// Finds and returns the first input that contains a token with the given policy ID.
///
/// # Arguments
/// * `inputs` - The list of inputs to search.
/// * `policy_id` - The policy ID to look for.
///
/// # Returns
/// The first `Input` that contains a token with the specified policy ID. Fails if no such input is found.
pub fn find_ref_input(inputs: List<Input>, policy_id: PolicyId) {
  expect Some(input) =
    list.find(
      inputs,
      fn(i) { list.has(i.output.value |> assets.policies, policy_id) },
    )
  input
}

/// Checks that there is exactly one output sent to a specific address containing a token with a given policy ID.
///
/// # Arguments
/// * `outputs` - The list of outputs to check.
/// * `policy_id` - The policy ID of the token.
/// * `address` - The address the output must be sent to.
///
/// # Returns
/// `True` if the condition is met, `False` otherwise.
pub fn must_have_one_output_with_policy(
  outputs: List<Output>,
  policy_id: PolicyId,
  address: Address,
) {
  list.count(
    outputs,
    fn(o) {
      and {
        list.has(o.value |> assets.policies, policy_id)?,
        (o.address == address)?,
      }
    },
  ) == 1
}

/// Ensures that the correct amount of remaining Asset and Credit tokens are sent back to the user's script address after a burn operation.
///
/// # Arguments
/// * `tx` - The current transaction.
/// * `asset_pid` - The policy ID for Asset tokens.
/// * `credit_pid` - The policy ID for Credit tokens.
/// * `asset_tkn` - The asset name for Asset tokens.
/// * `credit_tkn` - The asset name for Credit tokens.
/// * `burn_qty` - The quantity of tokens being burned (a negative value).
/// * `user_script` - The user's script address where the remaining tokens should be sent.
pub fn must_send_remaining_token_to_addr(
  tx: Transaction,
  asset_pid: PolicyId,
  credit_pid: PolicyId,
  asset_tkn: ByteArray,
  credit_tkn: ByteArray,
  burn_qty: Int,
  user_script: Address,
) {
  let (asset_qty, credit_qty) =
    do_total_token_amount(
      tx.inputs,
      asset_pid,
      credit_pid,
      asset_tkn,
      credit_tkn,
      0,
      0,
    )

  let o_asset = asset_qty + burn_qty
  let o_credit = credit_qty + burn_qty

  if o_asset == 0 && o_credit == 0 {
    True
  } else {
    let expected_output =
      value.from_tokens(
        [
          Token { pid: asset_pid, tkn: asset_tkn, amt: o_asset },
          Token { pid: credit_pid, tkn: credit_tkn, amt: o_credit },
        ],
      )
    payout.at_least(user_script, expected_output, tx.outputs)?
  }
}

/// Checks if the campaign's current state matches the expected state.
///
/// # Arguments
/// * `datum` - The `CampaignDatum` of the campaign.
/// * `state` - The expected `CampaignState`.
///
/// # Returns
/// `True` if the states match, `False` otherwise.
pub fn campaign_state(datum: CampaignDatum, state: CampaignState) -> Bool {
  datum.state == state
}

/// Validates that a backer is refunded at least the amount they contributed.
///
/// # Arguments
/// * `tx` - The current transaction.
/// * `script_address` - The address of the campaign script.
/// * `backer_datum` - The `BackerDatum` identifying the backer to be refunded.
///
/// # Returns
/// `True` if the output lovelace to the backer is greater than or equal to the input lovelace from the backer.
pub fn must_refund(
  tx: Transaction,
  script_address: Address,
  backer_datum: BackerDatum,
) {
  let backer_datum_data: Data = backer_datum
  let backer_address: Address = addresses.from_wallet(backer_datum)

  // Sum all lovelace from inputs belonging to the backer at the script address.
  let sum_input =
    fn(sum, Input { output: Output { address, datum, value, .. }, .. }) {
      if address == script_address {
        when datum is {
          InlineDatum(input_datum) ->
            if input_datum == backer_datum_data {
              assets.lovelace_of(value) + sum
            } else {
              sum
            }
          _ -> sum
        }
      } else {
        sum
      }
    }
  let input_lovelace = list.reduce(tx.inputs, 0, sum_input)

  // Sum all lovelace from outputs sent to the backer's address.
  let sum_output =
    fn(sum, Output { address, value, .. }) {
      if address == backer_address {
        assets.lovelace_of(value) + sum
      } else {
        sum
      }
    }
  let output_lovelace = list.reduce(tx.outputs, 0, sum_output)

  output_lovelace >= input_lovelace
}

/// Ensures that all funds contributed by backers are consolidated into a single output at the script address
/// when a campaign is finished.
///
/// # Arguments
/// * `tx` - The current transaction.
/// * `script_address` - The address of the campaign script.
/// * `campaign_datum` - The `CampaignDatum` for the finished campaign.
///
/// # Returns
/// `True` if an output with the correct datum and sufficient funds is found at the script address.
pub fn must_pay_to_script(
  tx: Transaction,
  script_address: Address,
  campaign_datum: CampaignDatum,
) {
  let campaign_datum_data: Data = campaign_datum
  // Sum all lovelace from inputs that are from backers.
  let sum_support =
    fn(sum, Input { output: Output { address, datum, value, .. }, .. }) {
      if address == script_address {
        when datum is {
          InlineDatum(input_datum) ->
            if input_datum is BackerDatum {
              assets.lovelace_of(value) + sum
            } else {
              sum
            }
          _ -> sum
        }
      } else {
        sum
      }
    }
  let supports = tx.inputs |> list.reduce(0, sum_support)
  // Check if any output at the script address contains the campaign datum and at least the total supported amount.
  list.any(
    tx.outputs,
    fn(o) {
      when o.datum is {
        InlineDatum(datum_data) -> and {
            campaign_datum_data == datum_data,
            o.address == script_address,
            assets.lovelace_of(o.value) >= supports,
          }
        _ -> False
      }
    },
  )
}

/// Updates the campaign datum by marking the next uncompleted milestone as complete.
///
/// # Arguments
/// * `datum` - The current `CampaignDatum`.
///
/// # Returns
/// A new `CampaignDatum` with the next milestone in the list set to `True`.
pub fn updating_datum_milestone(datum: CampaignDatum) -> CampaignDatum {
  let milestones: Milestone = datum.milestone
  expect Some(index) = list.index_of(milestones, False)
  let updated_milestones =
    list.indexed_map(
      milestones,
      fn(i, m) {
        if i == index {
          !m
        } else {
          m
        }
      },
    )

  CampaignDatum { ..datum, milestone: updated_milestones }
}

/// Validates the payout for a completed milestone.
/// It ensures that the campaign goal has been met and that the creator and platform receive their correct share of the funds for the current milestone.
///
/// # Arguments
/// * `tx` - The current transaction.
/// * `self_address` - The address of the campaign script.
/// * `campaign_datum` - The `CampaignDatum` of the campaign.
pub fn must_reach_goal_and_send_to_creator(
  tx: Transaction,
  self_address: Address,
  campaign_datum: CampaignDatum,
) {
  let CampaignDatum { creator, milestone, .. } = campaign_datum
  let remaining_milestone = list.count(milestone, fn(m) { m == False })

  // Sum the total funds collected, which are held in the CampaignDatum UTxO.
  let sum_support =
    fn(sum, Input { output: Output { address, datum, value, .. }, .. }) {
      if address == self_address {
        when datum is {
          InlineDatum(input_datum) ->
            if input_datum is CampaignDatum {
              assets.lovelace_of(value) + sum
            } else {
              sum
            }
          _ -> sum
        }
      } else {
        sum
      }
    }
  let supports = tx.inputs |> list.reduce(0, sum_support)
  let (platform_pay, creator_pay) = calculate_payout_platform_creator(supports)
  let creator_address = addresses.from_wallet(creator)

  // Sum the total lovelace paid to the creator in this transaction.
  let sum_creator =
    fn(sum, Output { address, value, .. }) {
      if address == creator_address {
        assets.lovelace_of(value) + sum
      } else {
        sum
      }
    }

  // Sum the total lovelace paid to the platform in this transaction.
  let sum_platform =
    fn(sum, Output { address, value, .. }) {
      when address.payment_credential is {
        VerificationKey(vkh) ->
          if vkh == constants.royalty_addr.pkh {
            assets.lovelace_of(value) + sum
          } else {
            sum
          }
        _ -> sum
      }
    }

  // Sum the total lovelace returned to the script address.
  let sum_script =
    fn(sum, Output { address, value, .. }) {
      if address == self_address {
        assets.lovelace_of(value) + sum
      } else {
        sum
      }
    }

  // Ensure that if there are remaining milestones, the correct amount of funds is returned to the script.
  let to_script =
    if remaining_milestone > 1 {
      list.reduce(tx.outputs, 0, sum_script) >= supports - supports / remaining_milestone
    } else {
      True
    }

  and {
    to_script,
    // Verify that the creator receives at least their share for the current milestone.
    list.reduce(tx.outputs, 0, sum_creator) >= creator_pay / remaining_milestone,
    // Verify that the platform receives at least its share for the current milestone.
    list.reduce(tx.outputs, 0, sum_platform) >= platform_pay / remaining_milestone,
  }
}

/// A private helper function to calculate the payout distribution between the platform and the campaign creator.
///
/// # Arguments
/// * `amount` - The total amount to be distributed.
///
/// # Returns
/// A tuple containing the platform's share and the creator's share.
fn calculate_payout_platform_creator(amount: Int) -> (Int, Int) {
  let platform = amount * 5 / 100
  let seller = amount - platform
  (platform, seller)
}

/// Finds and returns the first transaction output that contains a specific NFT.
///
/// # Arguments
/// * `outputs` - The list of outputs to search.
/// * `pid` - The policy ID of the NFT.
/// * `tkn` - The asset name of the NFT.
///
/// # Returns
/// The first `Output` that contains the specified NFT. Fails if no such output is found.
pub fn output_by_nft(
  outputs: List<Output>,
  pid: PolicyId,
  tkn: AssetName,
) -> Output {
  when outputs is {
    [output, ..rest] ->
      if value.prove_exact_nft(output.value, pid, tkn) {
        output
      } else {
        output_by_nft(rest, pid, tkn)
      }
    [] -> fail @"No Output Found In Outputs"
  }
}

/// Extracts and returns a `GovernanceDatum` from a generic `Data` object.
///
/// # Arguments
/// * `data` - The `Data` object to be converted.
///
/// # Returns
/// A `GovernanceDatum` if the conversion is successful. Fails if the `Data` does not match the `GovernanceDatum` structure.
pub fn governance_datum_from_data(data: Data) -> GovernanceDatum {
  expect GovernanceDatum {
    proposal_id,
    submitted_by,
    proposal_action,
    votes,
    votes_count,
    deadline,
    proposal_state,
  } = data
  GovernanceDatum {
    proposal_id,
    submitted_by,
    proposal_action,
    votes,
    votes_count,
    deadline,
    proposal_state,
  }
}

// ---
pub fn get_vote(votes: Votes, voter: Voter) -> Vote {
  when votes is {
    [vote, ..rest] ->
      if vote.voter == voter {
        vote.vote
      } else {
        get_vote(rest, voter)
      }
    [] -> fail @"No Votes Found"
  }
}
