use cardano/assets.{PolicyId}
use cardano/transaction.{OutputReference}

/// A redeemer for the `identification_nft` validator, specifying whether to mint or burn the NFT.
pub type Action {
  /// The action to mint the Identification NFT.
  Mint
  /// The action to burn the Identification NFT.
  Burn
}

/// A redeemer for the `validation_contract` validator.
pub type ProjectValidationRedeemer {
  /// The action to perform: 0 for accepting a project, 1 for rejecting it.
  action: Int,
  /// The amount of Credit Tokens to be minted upon project approval.
  amount: Int,
  /// The output reference of the UTxO being spent.
  oref: OutputReference,
}

/// A redeemer for the `marketplace` validator.
pub type MarketplaceRedeemer {
  /// The action to purchase an asset from the marketplace.
  Buy
  /// The action for the owner to withdraw their asset from the marketplace.
  Withdraw
}

/// A redeemer for the `asset_minter` validator, used when burning Asset Tokens.
pub type AssetBurnRedeemer {
  /// The policy ID of the Credit Tokens being burned alongside the Asset Tokens.
  credit_policy_id: PolicyId,
}

/// A redeemer for the `crowdfunding` validator, specifying the action to be taken on a crowdfunding campaign.
pub type CampaignAction {
  /// The action for a backer to contribute funds to a campaign.
  Support
  /// The action to cancel a campaign.
  Cancel
  /// The action to successfully finish a campaign.
  Finish
  /// The action for a backer to claim a refund from a cancelled campaign.
  Refund
  /// The action for the campaign creator to release milestone-based funds.
  Release
}
