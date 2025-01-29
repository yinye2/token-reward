# Token Reward Distribution Contract

A Clarity smart contract for managing token reward distributions on the Stacks blockchain. This contract enables automated distribution of reward tokens to eligible participants with built-in administrative controls and safety features.

## Features

- Token reward distribution to eligible participants
- Configurable reward amounts per participant
- Bulk participant management
- Collection period for unclaimed tokens
- Event logging system
- Comprehensive administrative controls
- Read-only functions for contract state queries

## Contract Architecture

### Core Components

1. **Fungible Token**
   - Custom reward token implementation
   - Initial supply: 1,000,000,000 tokens
   - Minted to contract owner upon initialization

2. **Participant Management**
   - Individual and bulk participant registration
   - Eligibility tracking
   - Claim status monitoring

3. **Distribution Controls**
   - Configurable reward amounts
   - Adjustable collection period
   - Active/inactive status management

### Error Codes

- `u100`: Not contract owner
- `u101`: Reward already claimed
- `u102`: Participant not eligible
- `u103`: Insufficient token balance
- `u104`: Reward not active
- `u105`: Invalid amount
- `u106`: Collection period not ended
- `u107`: Invalid participant
- `u108`: Invalid timeframe

## Public Functions

### Administrative Functions

```clarity
(add-eligible-participant (participant-address principal))
(remove-eligible-participant (participant-address principal))
(bulk-add-eligible-participants (participant-addresses (list 200 principal)))
(update-reward-amount (new-amount uint))
(update-collection-period (new-period uint))
```

### Participant Functions

```clarity
(claim-reward-tokens)
```

### Recovery Functions

```clarity
(collect-unclaimed-tokens)
```

### Read-Only Functions

```clarity
(get-reward-active-status)
(is-participant-eligible (participant-address principal))
(has-participant-claimed-reward (participant-address principal))
(get-participant-claimed-amount (participant-address principal))
(get-total-tokens-released)
(get-reward-amount-per-participant)
(get-collection-period)
(get-reward-start-block)
(get-event (event-id uint))
```

## Usage Examples

### Adding an Eligible Participant

```clarity
;; Only contract owner can add participants
(contract-call? .token-reward add-eligible-participant 'SP2J6ZY48GV1EZ5V2V5RB9MP66SW86PYKKNRV9EJ7)
```

### Claiming Rewards

```clarity
;; Must be called by eligible participant
(contract-call? .token-reward claim-reward-tokens)
```

### Checking Participant Status

```clarity
;; Anyone can check eligibility
(contract-call? .token-reward is-participant-eligible 'SP2J6ZY48GV1EZ5V2V5RB9MP66SW86PYKKNRV9EJ7)
```

## Security Considerations

1. **Access Control**
   - Administrative functions restricted to contract owner
   - Participant validation before reward distribution
   - Double-claim prevention

2. **Token Safety**
   - Balance checks before transfers
   - Unclaimed token recovery mechanism
   - Configurable collection period

3. **Data Validation**
   - Input validation for all public functions
   - Safe math operations
   - Status checks before critical operations

## Events

The contract emits events for important actions:
- Participant additions/removals
- Reward claims
- Amount updates
- Period modifications
- Token collections

## Development Setup

1. Install Clarinet
2. Clone the repository
3. Run Clarinet console:
   ```bash
   clarinet console
   ```

## Testing

Recommended test scenarios:
1. Participant registration
2. Reward claiming
3. Administrative controls
4. Error conditions
5. Token operations

## Deployment

1. Build the contract:
   ```bash
   clarinet build
   ```

2. Deploy using Stacks wallet or command line tools
3. Initialize contract parameters
4. Add initial participants

