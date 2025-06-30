use aiken/crypto.{VerificationKeyHash}
use cardano/assets.{AssetName, PolicyId}

/// Represents a specific type of asset, uniquely identified by its policy ID and asset name.
pub type AssetClass {
  /// The policy ID of the asset.
  policy_id: PolicyId,
  /// The name of the asset.
  asset_name: AssetName,
}

/// A type alias for `VerificationKeyHash` to specifically represent a payment key hash.
pub type PaymentKeyHash =
  VerificationKeyHash

/// A type alias for `VerificationKeyHash` to specifically represent a stake key hash.
pub type StakeKeyHash =
  VerificationKeyHash

/// A tuple that combines a `PaymentKeyHash` and a `StakeKeyHash` to represent the core components of a Cardano address.
pub type AddressTuple =
  (PaymentKeyHash, StakeKeyHash)

/// A type alias for `Int` used to specify the minimum number of required signatures in a multi-signature scheme.
pub type Atleast =
  Int

/// Defines a multi-signature scheme.
pub type Multisig {
  /// The minimum number of signatures required for a transaction to be valid.
  required: Atleast,
  /// A list of the verification key hashes of the authorized signers.
  signers: List<VerificationKeyHash>,
}

// ---- DAO UTILS
// utils
/// Represents the possible states of a governance proposal.
pub type ProposalState {
  /// The proposal is currently active and open for voting.
  InProgress
  /// The proposal has been successfully executed.
  Executed
  /// The proposal has been rejected.
  Rejected
}

/// A type alias for `VerificationKeyHash` to represent a voter's identity.
pub type Voter =
  VerificationKeyHash

/// A record to store the count of votes for a proposal.
pub type VotesCount {
  /// The number of 'Yes' votes.
  yes: Int,
  /// The number of 'No' votes.
  no: Int,
  /// The number of 'Abstain' votes.
  abstain: Int,
}

/// Represents the possible voting options for a governance proposal.
pub type Vote {
  /// A vote in favor of the proposal.
  Yes
  /// A vote against the proposal.
  No
  /// A vote to abstain from the decision.
  Abstain
  /// A placeholder state for a vote that has not yet been cast.
  Pending
}

/// Defines the possible actions that can be taken through a governance proposal.
pub type ProposalAction {
  /// Update the platform's fee amount.
  FeeAmountUpdate(Int)
  /// add new action in similar way
  /// Action(UpdatedValue)
  DaoAction(VerificationKeyHash)
}

/// A type alias for a dictionary that maps voters to their votes on a proposal.
pub type VotesStruct {
  voter: Voter,
  vote: Vote,
}

pub type Votes =
  List<VotesStruct>
