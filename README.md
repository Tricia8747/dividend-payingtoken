# Dividend-PayingToken (DPT)

A Clarity smart contract implementation of a dividend-paying token on the Stacks blockchain that follows the SIP-010 fungible token standard.

## Overview

This contract implements a fungible token that enables automatic dividend distribution in STX (Stacks native token) to all token holders. Token holders receive dividends proportional to their token balance.

## Features

- 📝 Full SIP-010 fungible token standard compliance
- 💰 Automatic STX dividend distribution
- 🔄 Magnified dividend calculations for handling fractions
- 🔒 Secure transfer mechanics with authorization checks
- 💸 On-demand dividend withdrawal system

## Contract Functions

### Token Functions (SIP-010)

- `get-name`: Returns the token name "DividendToken"
- `get-symbol`: Returns the token symbol "DIV"
- `get-decimals`: Returns the decimal places (6)
- `get-balance`: Get token balance for an account
- `get-total-supply`: Get the total supply of tokens
- `transfer`: Transfer tokens between accounts with memo support

### Dividend Functions

- `deposit-dividends`: Deposit STX for distribution as dividends
- `withdrawable-dividends`: Check pending dividends for an account
- `withdraw-dividends`: Withdraw available dividends in STX

### Administrative Functions

- `mint`: Create new tokens (owner-only)

## Error Codes

- `ERR_UNAUTHORIZED (u100)`: Unauthorized operation attempt
- `ERR_INSUFFICIENT_BALANCE (u101)`: Insufficient balance for transfer
- `ERR_FAILED_TO_TRANSFER (u102)`: STX transfer failure

## Technical Details

### Dividend Distribution Mechanism

The contract uses a magnification factor (`MAGNITUDE = u1000000000`) to handle fractional dividends accurately. Dividend corrections are tracked per account to ensure precise distribution.

### Storage

- `total-supply`: Total token supply
- `balances`: Map of account balances
- `magnified-dividend-per-share`: Current dividend rate
- `dividend-corrections`: Account-specific dividend adjustments
- `withdrawn-dividends`: Record of withdrawn dividends

## Usage

### Depositing Dividends

```clarity
(contract-call? .dividend-token deposit-dividends)
