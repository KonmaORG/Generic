use cardano/assets.{PolicyId}
use types/moment.{Moment}
use types/utils.{
  AssetClass, Multisig, ProposalAction, ProposalState, Voter, Votes, VotesCount,
}
use types/wallet.{Wallet}

/// The main configuration datum for the entire protocol.
pub type ConfigDatum {
  /// The wallet address where platform fees are collected.
  fees_address: Wallet,
  /// The amount of the platform fee.
  fees_amount: Int,
  /// The asset class (policy ID and asset name) of the fee token.
  fees_asset_class: AssetClass,
  /// The wallet address for spending-related operations.
  spend_address: Wallet,
  /// A list of supported project categories.
  categories: List<ByteArray>,
  /// The multi-signature group required to validate projects.
  multisig_validator_group: Multisig,
  /// The multi-signature group required to update this configuration datum.
  multisig_refutxoupdate: Multisig,
  /// The policy ID of the Asset Token.
  asset_policy_id: PolicyId,
  /// The policy ID of the Credit Token.
  credit_policy_id: PolicyId,
  /// The wallet address for the DAO.
  dao_policyid: PolicyId,
}

/// The datum for a project submitted for validation.
pub type ProjectDatum {
  /// The wallet of the project initiator.
  initiator: Wallet,
  /// A hash or identifier for the project's documentation.
  document: ByteArray,
  /// The category of the project.
  category: ByteArray,
  /// The asset name for the project's unique NFT.
  asset_name: ByteArray,
  /// The fee amount paid for project submission.
  fees_amount: Int,
  /// The asset class of the fee paid.
  fees_asset_class: AssetClass,
}

/// The datum for an asset listed on the marketplace.
pub type MarketplaceDatum {
  /// The wallet of the asset's owner (the seller).
  owner: Wallet,
  /// The price of the asset in Lovelace.
  amount: Int,
}

/// The datum associated with the minting of Asset Tokens.
pub type AssetDatum {
  /// The context related to the assets.
  context: ByteArray,
  /// The quantity of Asset Tokens to be minted.
  asset_qty: Int,
  /// The timestamp of the asset event.
  time: Int,
}

/// A configuration type holding the policy IDs for Asset and Credit Tokens.
pub type AssetCreditConfig {
  /// The policy ID of the Asset Token.
  asset_policy_id: PolicyId,
  /// The policy ID of the Credit Token.
  credit_policy_id: PolicyId,
}

/// Represents the possible states of a crowdfunding campaign.
pub type CampaignState {
  /// The initial state when a campaign is first created.
  Initiated
  /// The state when a campaign is active and accepting contributions.
  Running
  /// The state when a campaign has been cancelled.
  Cancelled
  /// The state when a campaign has successfully met its goal and ended.
  Finished
  /// The state when funds for a milestone have been released to the creator.
  Released
}

/// A type alias for a list of booleans, representing the completion status of campaign milestones.
pub type Milestone =
  List<Bool>

/// The datum for a crowdfunding campaign.
pub type CampaignDatum {
  /// The name of the campaign.
  name: ByteArray,
  /// The funding goal in Lovelace.
  goal: Int,
  /// The deadline for the campaign, as a POSIX timestamp.
  deadline: Int,
  /// The wallet of the campaign creator.
  creator: Wallet,
  /// A list representing the milestones of the campaign and their completion status.
  milestone: Milestone,
  /// The current state of the campaign.
  state: CampaignState,
  /// The fixed amount of reward tokens distributed per contribution fraction.
  fraction: Int,
}

/// The datum for a campaign backer, represented by their wallet.
pub type BackerDatum =
  Wallet

// -----DAO DATUM
/// The datum for a governance proposal.
pub type GovernanceDatum {
  /// A unique identifier for the proposal.
  proposal_id: ByteArray,
  /// The voter who submitted the proposal.
  submitted_by: Voter,
  /// The action to be taken if the proposal is approved.
  proposal_action: ProposalAction,
  /// A dictionary mapping voters to their votes.
  votes: Votes,
  /// A count of the 'Yes', 'No', and 'Abstain' votes.
  votes_count: VotesCount,
  /// The deadline for voting on the proposal.
  deadline: Moment,
  /// The current state of the proposal (e.g., InProgress, Executed, Rejected).
  proposal_state: ProposalState,
}
