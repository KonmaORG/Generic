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
