# Generic System Architecture Documentation

## Table of Contents

- [Overview](#overview)
- [System Structure](#system-structure)
- [Key Components](#key-components)
  - [Configuration (`aiken.toml`)](#configuration-aikentoml)
  - [Constants (`lib/constants.ak`)](#constants-libconstantsak)
  - [Data Types (`lib/types/*.ak`)](#data-types-libtypesak)
  - [Utility Functions (`lib/functions/utils.ak`)](#utility-functions-libfunctionsutilsak)
  - [Validators (`validators/*.ak`)](#validators-validatorsak)
    - [1. `validation_contract.ak`](#1-validation_contractak)
    - [2. `asset_minter.ak`](#2-asset_minterak)
    - [3. `user_script.ak`](#3-user_scriptak)
    - [4. `config_datum_holder.ak`](#4-config_datum_holderak)
    - [5. `crowdfunding.ak`](#5-crowdfundingak)
    - [6. `identification_nft.ak`](#6-identification_nftak)
    - [7. `marketplace.ak`](#7-marketplaceak)
    - [8. `dao.ak`](#8-daoak)
- [Flow](#flow)
  - [Detailed Workflow](#detailed-workflow)
  - [Flowchart](#flowchart)
- [Glossary](#glossary)
- [Use Case Examples](#use-case-examples)
  - [Supply Chain Provenance](#supply-chain-provenance)
  - [Digital Collectibles](#digital-collectibles)
  - [Loyalty Rewards Program](#loyalty-rewards-program)
- [Error Handling](#error-handling)
- [Usage](#usage)

## Overview

This document outlines a generic Cardano-based system architecture implemented with Aiken smart contracts, leveraging Plutus v3. The system supports token management, project validation, crowdfunding, and marketplace trading, using two token types: **Asset Tokens** (representing tangible or intangible assets) and **Credit Tokens** (representing validated credits or rewards). It includes validators for initiating and validating projects, minting/burning tokens, managing crowdfunding campaigns, and facilitating marketplace transactions, with a configuration system secured by an identification NFT.

Designed for flexibility, this architecture can be adapted to various domains, such as supply chain tracking, digital collectibles, or loyalty programs, providing a robust framework for decentralized applications on Cardano.

## System Structure

- **lib/**: Supporting modules for constants, utility functions, and data types.
  - `constants.ak`: Defines constants (e.g., identification token name, royalty percentage).
  - `functions/utils.ak`: Utility functions for validation and token handling.
  - `types/datum.ak`, `types/redeemer.ak`, `types/utils.ak`: Data types for datums, redeemers, and utilities.
- **validators/**: Smart contract validators:
  - `validation_contract.ak`: Project initiation and validation with multisig.
  - `asset_minter.ak`: Mints/burns asset and credit tokens.
  - `user_script.ak`: Manages user interactions with tokens.
  - `config_datum_holder.ak`: Stores configuration data and identification NFT.
  - `crowdfunding.ak`: Manages crowdfunding campaigns.
  - `identification_nft.ak`: Mints/burns identification NFTs.
  - `marketplace.ak`: Handles marketplace trading with royalties.
  - `dao.ak`: Manages governance proposals, voting, and execution for decentralized decision-making.
- **aiken.toml**: System configuration with dependencies.
- **README.md**: Instructions for building, testing, and documentation.
- **.github/workflows/continuous-integration.yml**: CI pipeline.

## Key Components

### Configuration (`aiken.toml`)

- **Name**: Generic system
- **Version**: `0.0.0`
- **Compiler**: Aiken `v1.1.17`
- **Plutus Version**: `v3`
- **Dependencies**:
  - `aiken-lang/stdlib` (v2.2.0)
  - `logical-mechanism/assist` (v0.5.1)

### Constants (`lib/constants.ak`)

- **Identification Token**: A unique token name for referencing configuration data.
- **Royalty Amount**: 3% (configurable fee for marketplace transactions).
- **Royalty Address**: A wallet address for platform fees.

### Data Types (`lib/types/*.ak`)

- **ConfigDatum**: Stores fees, addresses, categories, multisig settings, asset/credit policy IDs.
- **ProjectDatum**: Defines project details (initiator, document, category, fees).
- **MarketplaceDatum**: Tracks ownership and amounts in marketplace transactions.
- **AssetDatum**: Specifies asset token details (context, quantity, timestamp).
- **CampaignDatum**: Manages crowdfunding campaign data (name, goal, deadline, milestones, state).
- **BackerDatum**: Represents a backer’s wallet.
- **Redeemers**: `Mint`, `Burn`, `Buy`, `Withdraw`, `CampaignAction` (`Support`, `Cancel`, `Finish`, `Refund`, `Release`).
- **Utilities**: `AssetClass`, `PaymentKeyHash`, `StakeKeyHash`, `AddressTuple`, `Multisig`.

### Utility Functions (`lib/functions/utils.ak`)

- `is_category_from_supported_categories`: Validates project categories.
- `must_send_nft_and_datum_to_script`: Ensures NFT and datum outputs to scripts.
- `must_burn_less_than_0`: Verifies token burning quantities.
- `ref_datum_by_nft`: Retrieves configuration datum using an NFT.
- `calculate_payout_royalty`: Splits marketplace payments (3% to platform).
- `must_reach_goal_and_send_to_creator`: Ensures crowdfunding payouts meet goals.

### Validators (`validators/*.ak`)

#### 1. `validation_contract.ak`

- **Purpose**: Manages project initiation and validation.
- **Contracts**:
  - **Initiator**: Mints project NFTs, ensuring valid categories and fees.
  - **Validator**: Approves/rejects projects with multisig, mints credit tokens on approval.
- **Logic**:
  - Initiation: Verifies category and sends NFT to validator contract.
  - Validation: Burns NFT; mints credit tokens on approval, burns tokens on rejection.

#### 2. `asset_minter.ak`

- **Purpose**: Mints/burns asset and credit tokens.
- **Logic**:
  - Mints asset tokens with matching datum and quantity.
  - Burns asset and credit tokens in equal quantities for reconciliation.
- **Redeemer**: `AssetDatum` (mint), `AssetBurnRedeemer` (burn).

#### 3. `user_script.ak`

- **Purpose**: Manages user interactions with asset/credit tokens.
- **Logic**:
  - Burns asset and credit tokens equally.
  - Allows credit token withdrawal.
  - Tokens are non-transferable, only burnable or withdrawable (credit tokens).
- **Redeemer**: 0 (burn), 1 (withdraw).

#### 4. `config_datum_holder.ak`

- **Purpose**: Stores configuration datum and identification NFT.
- **Logic**: Requires multisig to spend.

#### 5. `crowdfunding.ak`

- **Purpose**: Manages crowdfunding campaigns.
- **Actions**:
  - **Support**: Backers contribute and receive reward tokens.
  - **Cancel**: Cancels campaign (creator or platform).
  - **Finish**: Marks campaign as finished, burns tokens.
  - **Refund**: Refunds backers in cancelled campaigns.
  - **Release**: Releases funds per milestone.
- **Logic**:
  - Ensures future deadlines and unset milestones.
  - Verifies signatures and state transitions.

#### 6. `identification_nft.ak`

- **Purpose**: Mints/burns identification NFT for configuration reference.
- **Logic**: Mints one NFT or burns it.

#### 7. `marketplace.ak`

- **Purpose**: Facilitates credit token trading with royalties.
- **Actions**:
  - **Buy**: Pays seller and platform (3% royalty).
  - **Withdraw**: Seller withdraws funds.
- **Logic**: Ensures correct payouts and signatures.

#### 8. `dao.ak`

- **Purpose**: Manages the lifecycle of governance proposals in a Decentralized Autonomous Organization (DAO), enabling proposal submission, voting, execution, and rejection.
- **Actions**:
  - **SubmitProposal**: Creates a new proposal with a unique NFT, requiring the proposer’s signature.
  - **VoteProposal**: Allows authorized voters to cast votes (`Yes`, `No`, `Abstain`) before the proposal’s deadline.
  - **ExecuteProposal**: Executes approved proposals (e.g., updating platform fees) after the voting deadline, requiring more `Yes` than `No` votes.
  - **RejectProposal**: Rejects proposals with more `No` than `Yes` votes after the deadline.
- **Logic**:
  - Proposals are represented by `GovernanceDatum`, storing proposal ID, submitter, action, votes, vote counts, deadline, and state (`InProgress`, `Executed`, `Rejected`).
  - Uses an NFT (policy ID from `ConfigDatum`) to track proposal UTxOs.
  - Voting requires the voter to be in the `ConfigDatum`’s voter list, with no prior vote cast.
  - Execution updates the `ConfigDatum` (e.g., fee changes) and transitions the proposal to `Executed`.
  - Rejection transitions the proposal to `Rejected` if `No` votes exceed `Yes` votes.
- **Redeemer**: `GovernanceRedeemer` (`SubmitProposal`, `VoteProposal`, `ExecuteProposal`, `RejectProposal`).

## Flow

The system orchestrates a workflow for token management, project validation, crowdfunding, and trading. Below is a detailed explanation, followed by a flowchart.

### Detailed Workflow

1. **Project Initiation**:

   - An initiator submits a project via the `initiator` contract in `validation_contract.ak`.
   - A `ProjectDatum` (category, initiator, fees) is provided.
   - The contract validates the category and mints a project NFT, sent to the `validator` contract with fees to the platform address.

2. **Project Validation**:

   - Validators, defined in the `ConfigDatum`’s multisig settings, review the project via `validator`.
   - **Approval**:
     - Requires multisig signatures.
     - Burns the project NFT.
     - Mints credit tokens (derived from output reference) and sends them to the initiator.
   - **Rejection**:
     - Requires multisig signatures.
     - Burns the project NFT and associated tokens.
   - Configuration is referenced via the identification NFT.

3. **Asset Token Minting**:

   - Entities mint asset tokens via `asset_minter`.
   - An `AssetDatum` (context, quantity, timestamp) is provided.
   - Tokens are minted and sent to `user_script`, ensuring datum and quantity match.
   - Asset tokens are non-transferable, stored in `user_script`.

4. **Asset/Credit Reconciliation**:

   - Users burn asset and credit tokens via `user_script` to reconcile assets.
   - The burn action requires equal quantities of both tokens.
   - Remaining credit tokens are sent to the user’s script address.
   - Asset and credit tokens are non-transferable, only burnable or withdrawable (credit tokens).

5. **Marketplace Trading**:

   - Initiators trade credit tokens via `marketplace`.
   - **Buy**:
     - Buyers purchase credit tokens, splitting payment (3% to platform, remainder to seller).
   - **Withdraw**:
     - Sellers withdraw funds, requiring their signature.
   - Transactions use `MarketplaceDatum` to track ownership and amounts.

6. **Crowdfunding**:

   - Initiators raise funds via `crowdfunding`.
   - A campaign (`CampaignDatum`) is created, minting reward tokens.
   - **Support**: Backers contribute funds, receiving proportional reward tokens.
   - **Cancel**: Creator or platform cancels, refunding backers.
   - **Finish**: Marks campaign completion, burning reward tokens.
   - **Refund**: Refunds backers in cancelled campaigns.
   - **Release**: Releases funds per milestone, updating milestone status.
   - State transitions are validated with signatures.

7. **DAO Governance**:
   - **Proposal Submission**: A voter submits a proposal via `dao.ak`’s minting policy, creating a proposal NFT and `GovernanceDatum`.
   - **Voting**: Authorized voters cast votes (`Yes`, `No`, `Abstain`) before the deadline, updating the `GovernanceDatum`.
   - **Execution/Rejection**: After the deadline, proposals with more `Yes` votes are executed (e.g., updating platform fees), while those with more `No` votes are rejected. The proposal NFT tracks the UTxO.
   - Configuration is referenced via the identification NFT.

### Flowchart

```mermaid
graph TD
    A[Initiator Submits Project<br>initiator] -->|Mints Project NFT| B[Project Validation<br>validator]
    B -->|Multisig Approval| C[Burn Project NFT<br>Mint Credit Tokens]
    B -->|Multisig Rejection| D[Burn Project NFT<br>Burn Tokens]
    C --> E[Send Credit Tokens to Initiator]
    E --> F[Trade Credit Tokens<br>marketplace]
    E --> G[Reconcile Assets<br>user_script]
    H[Entity Mints Asset Tokens<br>asset_minter] --> I[Store Asset Tokens<br>user_script]
    I --> G
    F -->|Buy/Withdraw| J[Pay Seller & Platform]
    K[Initiator Starts Crowdfunding<br>crowdfunding] --> L[Backers Support]
    L --> M[Cancel/Finish/Refund/Release]
    M -->|Release| N[Pay Creator per Milestone]
        O[Voter Submits Proposal<br>dao] -->|Mints Proposal NFT| P[Vote on Proposal]
    P -->|After Deadline| Q{Outcome}
    Q -->|Yes > No| R[Execute Proposal<br>Update Config]
    Q -->|No > Yes| S[Reject Proposal]
```

## Glossary

- **Asset Token**: Represents tangible/intangible assets, minted by entities, non-transferable, burnable for reconciliation.
- **Credit Token**: Represents validated credits/rewards, minted upon project approval, tradable, burnable for reconciliation.
- **ConfigDatum**: Stores platform configuration (fees, addresses, multisig, policy IDs).
- **Identification NFT**: A unique NFT for referencing `ConfigDatum` in transactions.
- **Multisig**: Multi-signature validation requiring a minimum number of signatures.
- **Project NFT**: A token representing a project during validation, burned upon approval/rejection.
- **ProjectDatum**: Defines project details (initiator, category, fees).
- **MarketplaceDatum**: Tracks marketplace transaction data (owner, amount).
- **CampaignDatum**: Manages crowdfunding campaign data (name, goal, deadline, milestones, state).
- **BackerDatum**: Represents a backer’s wallet in crowdfunding.
- **Redeemer**: Specifies validator actions (e.g., `Mint`, `Burn`, `Buy`, `Support`).
- **Royalty**: A 3% fee paid to the platform in marketplace transactions.
- **Milestone**: A boolean list in `CampaignDatum` tracking crowdfunding progress.
- **GovernanceDatum**: Stores DAO proposal details (ID, submitter, action, votes, vote counts, deadline, state).
- **Proposal NFT**: A unique NFT representing a DAO proposal, used to track its UTxO.
- **ProposalAction**: Defines the action of a DAO proposal (e.g., `FeeAmountUpdate` for updating platform fees).
- **ProposalState**: The state of a DAO proposal (`InProgress`, `Executed`, `Rejected`).
- **VotesCount**: Tracks the number of `Yes`, `No`, and `Abstain` votes for a proposal.

## Use Case Examples

### Supply Chain Provenance

- **Context**: A company tracks product provenance (e.g., organic coffee) on Cardano.
- **Implementation**:
  - **Asset Tokens**: Represent product batches (e.g., coffee lot #123).
  - **Credit Tokens**: Represent verified certifications (e.g., organic status).
  - **Project Initiation**: A supplier submits a batch for certification.
  - **Validation**: Certifiers approve, minting credit tokens.
  - **Reconciliation**: Retailers burn asset and credit tokens to confirm sale of certified products.
  - **Marketplace**: Suppliers trade credit tokens for premium pricing.
  - **Crowdfunding**: Fund new sustainable farming initiatives.
  - **DAO Governance**: Suppliers propose and vote on new certification standards or fee adjustments, executed via dao.ak if approved.
- **Example**:
  - A supplier submits batch #123 (`ProjectDatum`: category "organic").
  - Certifiers approve, minting 1000 credit tokens.
  - A retailer buys 500 credit tokens and burns them with 500 asset tokens to certify sales.
  - The supplier crowdfunds $10,000 for a new farm, releasing funds per milestone.

### Digital Collectibles

- **Context**: A platform for creating and trading digital collectibles (e.g., NFTs).
- **Implementation**:
  - **Asset Tokens**: Represent unverified artwork submissions.
  - **Credit Tokens**: Represent approved collectibles.
  - **Project Initiation**: Artists submit artwork for review.
  - **Validation**: Curators approve, minting credit tokens as NFTs.
  - **Reconciliation**: Collectors burn asset and credit tokens to retire limited editions.
  - **Marketplace**: Trade collectibles with royalties to the platform.
  - **Crowdfunding**: Fund collaborative art projects.
  - **DAO Governance**: Artists and collectors vote on platform fee changes or new art categories, executed via dao.ak.
- **Example**:
  - An artist submits a digital painting (`ProjectDatum`: category "art").
  - Curators approve, minting 100 credit tokens (NFTs).
  - A collector buys 50 NFTs for 5000 ADA; 3% goes to the platform.
  - The artist crowdfunds 10,000 ADA for a new series, releasing funds after completing sketches.

### Loyalty Rewards Program

- **Context**: A retailer implements a blockchain-based loyalty program.
- **Implementation**:
  - **Asset Tokens**: Represent customer purchases.
  - **Credit Tokens**: Represent redeemable loyalty points.
  - **Project Initiation**: Retailers submit campaigns for point issuance.
  - **Validation**: Admins approve, minting credit tokens.
  - **Reconciliation**: Customers burn asset and credit tokens to redeem rewards.
  - **Marketplace**: Trade loyalty points among customers.
  - **Crowdfunding**: Fund community initiatives (e.g., charity drives).
  - **DAO Governance**: Retailers and customers vote on reward program rules or charity funding allocations, executed via dao.ak.
- **Example**:
  - A retailer submits a campaign (`ProjectDatum`: category "loyalty").
  - Admins approve, minting 10,000 credit tokens.
  - A customer earns 200 asset tokens from purchases, burns them with 200 credit tokens to redeem a discount.
  - Customers trade points on the marketplace; the retailer crowdfunds 5000 ADA for a charity event.

## Error Handling

- **Common Failures**:
  - Missing datum on input (`utils.ak`).
  - Invalid redeemer types (e.g., `asset_minter.ak`).
  - Incorrect address credentials (`user_script.ak`).
- **Protection**:
  - `expect` statements enforce valid inputs.
  - Multisig checks prevent unauthorized actions.
  - Token quantity validation ensures correct minting/burning.

## Usage

The system supports:

- **Token Management**: Asset/credit token minting and reconciliation.
- **Crowdfunding**: Milestone-based campaigns.
- **Marketplace**: Credit token trading with royalties.
- **Project Validation**: Multisig approval/rejection.
- **Configuration**: Secure storage with NFT referencing.
