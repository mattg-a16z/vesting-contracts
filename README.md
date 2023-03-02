# Vesting Contracts

This repo contains a set of vesting contracts using secured libraries with fairly comprehensive testing. The purpose of these contracts is to allow for smartchain enforced vesting terms that are virtually guaranteed to happen, so long as the smartchain itself does not suffer any sort of permanent outage or widespread data corruption.

## Contents

CliffedVestingWallet - A slightly modified version of OpenZeppelin's VestingWallet that allows for specification of a vesting cliff. The idea is that the contract is created by one party, and verified then funded by the other.

## Usage

Requires Foundry

```
forge install
forge build
forge test
```

## Disclaimer

_These smart contracts are being provided as is. No guarantee, representation or warranty is being made, express or implied, as to the safety or correctness of the user interface or the smart contracts. They have not been audited and as such there can be no assurance they will work as intended, and users may experience delays, failures, errors, omissions or loss of transmitted information. THE SMART CONTRACTS CONTAINED HEREIN ARE FURNISHED AS IS, WHERE IS, WITH ALL FAULTS AND WITHOUT WARRANTY OF ANY KIND, EXPRESS OR IMPLIED, INCLUDING ANY WARRANTY OF MERCHANTABILITY, NON- INFRINGEMENT OR FITNESS FOR ANY PARTICULAR PURPOSE. Further, use of any of these smart contracts may be restricted or prohibited under applicable law, including securities laws, and it is therefore strongly advised for you to contact a reputable attorney in any jurisdiction where these smart contracts may be accessible for any questions or concerns with respect thereto. Further, no information provided in this repo should be construed as investment advice or legal advice for any particular facts or circumstances, and is not meant to replace competent counsel. a16z is not liable for any use of the foregoing, and users should proceed with caution and use at their own risk. See a16z.com/disclosures for more info._
