# KipuBank V2 - Your Decentralized Banking Protocol

## What is KipuBank V2?

KipuBank V2 is an advanced smart contract that functions as a decentralized digital bank on the blockchain. It enables users to securely store both ETH and USDC tokens with enhanced features including price oracle integration, multi-token support, and sophisticated access controls. Think of it as a next-generation savings account with the transparency and security of blockchain technology.

## Key Features

✅ **Dual Asset Support** - Deposit and withdraw both ETH and USDC  
✅ **Chainlink Price Feeds** - Real-time ETH/USD price conversions  
✅ **Access Control** - Role-based permissions using OpenZeppelin Ownable  
✅ **Advanced Security** - Multiple validation modifiers and checks  
✅ **Transaction Tracking** - Comprehensive event logging  
✅ **Capacity Management** - Controlled bank capacity with real-time monitoring  
✅ **Decimal Conversion** - Automatic handling of different token decimals  

## Contract Deployment

### Prerequisites:
- MetaMask installed
- ETH for gas fees
- Remix IDE or Hardhat environment
- USDC token address for initialization
- Chainlink ETH/USD price feed address

### Deployment Steps:

1. **Compile the contract** in Remix IDE
2. **In "Deploy & Run Transactions" tab**:
   - Select "KipuBank" from contract dropdown
   - In "Deploy", provide four parameters:
     - `withdrawalLimit`: Maximum single withdrawal limit (e.g., 1000000000000000000 for 1 ETH)
     - `bankCapacity`: Total bank capacity (e.g., 10000000000000000000 for 10 ETH)
     - `_token`: USDC token contract address
     - `_ethUsdOracle`: Chainlink ETH/USD price feed address
3. **Click "Transact"** and confirm in MetaMask
4. **Your advanced banking protocol is now live on the blockchain!**

## How to Interact with the Contract

### `deposit(address _add, uint256 amount)`
**What it does**: Deposits either ETH or USDC into your bank account  
**How to use**:
- For ETH deposits: Set `_add` to `0x0000000000000000000000000000000000000000` and send ETH in "VALUE"
- For USDC deposits: Set `_add` to USDC token address and specify amount
- Call the function with appropriate parameters

### `withdrawETH(uint256 amount)`
**What it does**: Withdraws ETH from your account  
**Parameter**: `amount` - how much ETH to withdraw (in wei)  
**Features**: Automatic limit checks and balance validations

### `withdrawUSDC(uint256 amount)`
**What it does**: Withdraws USDC from your account  
**Parameter**: `amount` - how much USDC to withdraw (in USDC decimals)  
**Features**: Automatic price conversion and validation

### `myBalanceS()`
**What it does**: Shows your complete balance breakdown  
**Returns**: ETH balance, USDC balance, and total combined balance

### `availableCapacity()`
**What it does**: Indicates how much space remains in the bank

### `convertEthInUSD(uint256 _ethAmount)`
**What it does**: Converts ETH amount to USDC equivalent using Chainlink price feed

### `convertUsdcToEth(uint256 _usdcAmount)`
**What it does**: Converts USDC amount to ETH equivalent using Chainlink price feed

### `bankStatistics()` (Owner only)
**What it does**: Shows comprehensive bank status report  
**Returns**: Withdrawal limit, maximum capacity, current total, available space

### `transactionStatistics()` (Owner only)
**What it does**: Counts total deposits, withdrawals, and transactions

## Advanced Features

### Multi-Token Accounting
- Internal accounting handles both ETH and USDC balances
- Automatic decimal conversion between different token standards
- Unified total balance calculation

### Oracle Integration
- Real-time ETH/USD prices from Chainlink
- Heartbeat validation for price freshness
- Secure price feed updates

### Security Modifiers
- `validAmount`: Ensures non-zero amounts
- `withinWithdrawalLimit`: Enforces withdrawal limits
- `sufficientBalance`: Validates user has enough funds
- Role-based access control for administrative functions

## Technical Specifications

- **ETH Decimals**: 18
- **USDC Decimals**: 6  
- **Chainlink Price Feed Decimals**: 8
- **Conversion Factor**: 10²⁰ for precise calculations
- **Oracle Heartbeat**: 3600 seconds (1 hour)

KipuBank V2 represents a significant evolution in decentralized banking, combining robust security with flexible multi-asset support and real-time price oracle integration.
