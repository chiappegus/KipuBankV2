// SPDX-License-Identifier: MIT
pragma solidity >0.8.24;

// @dev Import OpenZeppelin's Ownable for access control
import {Ownable} from "@openzeppelin/contracts/access/Ownable.sol";

// @dev Import IERC20 interface for USDC token interactions
import {IERC20} from "@openzeppelin/contracts/token/ERC20/IERC20.sol";


// @dev Import Chainlink AggregatorV3Interface for price feeds
import {AggregatorV3Interface} from "@chainlink/contracts/src/v0.8/shared/interfaces/AggregatorV3Interface.sol";

/**
 * @title KipuBank
 * @notice A banking contract that allows deposits and withdrawals in ETH and USDC
 * @dev This contract implements banking functionality with price conversions between ETH and USDC
 */
contract KipuBank is Ownable {
    /*///////////////////////////////////
          Type declarations
    ///////////////////////////////////*/

    /// @notice Constant for oracle heartbeat timeout
    uint16 constant ORACLE_HEARTBEAT = 3600;
    
    /// @notice Constant for decimal conversion factor
    uint256 constant DECIMAL_FACTOR = 1 * 10 ** 20;

    /// @notice Chainlink price feed interface for ETH/USD
    AggregatorV3Interface public s_feeds; //0x694AA1769357215DE4FAC081bf1f309aDC325306 Ethereum ETH/USD



    /// @notice USDC token contract interface
    IERC20 public immutable USDC;

    /// @notice Maximum withdrawal limit per transaction
    uint256 public immutable WITHDRAWAL_LIMIT;

    /// @notice Maximum capacity of the bank
    uint256 public immutable BANK_CAPACITY;

    /*///////////////////////////////////
           State variables
    ///////////////////////////////////*/

    /// @notice Personal vault balances for each user
    mapping(address => uint256) private personalVaults;

    /// @notice Total ETH held by the contract
    uint256 public totalContractETH;

    /// @notice Balance structure for each user
    struct Balances {
        uint256 eth;
        uint256 usdc;
        uint256 total;
    }

    /// @notice User balances mapping
    mapping(address => Balances) private balance;

    /// @notice Total deposited amount across all users
    uint256 private totalDeposited;

    /// @notice Total number of deposits made
    uint256 private totalDepositsCount;

    /// @notice Total number of withdrawals made
    uint256 private totalWithdrawalsCount;

    /*///////////////////////////////////
               Events
    ///////////////////////////////////*/

    /// @notice Emitted when a successful ETH deposit is made
    event SuccessfulDepositEth(
        address indexed user,
        uint256 amount,
        bool inETH
    );

    /// @notice Emitted when a successful USDC deposit is made
    event SuccessfulDepositUsdc(
        address indexed user,
        uint256 amount,
        bool Usdc
    );

    /// @notice Emitted when a successful withdrawal is made
    event SuccessfulWithdrawal(address indexed user, uint256 amount);

    /// @notice Emitted when a successful USDC withdrawal is made
    event SuccessfulWithdrawalUSDC(address indexed user, uint256 amount);

    /// @notice Emitted when the Chainlink feed is updated
    event DonationsV2_ChainlinkFeedUpdated(address feed);

    /*///////////////////////////////////
               Errors
    ///////////////////////////////////*/

    /// @notice Error when oracle returns compromised data
    error KipuBank_OracleCompromised();
    
    /// @notice Error when oracle price is stale
    error KipuBank_StalePrice();
    
    /// @notice Error when amount is invalid (zero or negative)
    error InvalidAmount();
    
    /// @notice Error when withdrawal limit is exceeded
    error WithdrawalLimitExceeded();
    
    /// @notice Error when user has insufficient funds
    error InsufficientFunds();
    
    /// @notice Error when bank capacity is exceeded
    error BankCapacityExceeded();
    
    /// @notice Error when transfer fails
    error TransferFailed();
    
    /// @notice Error when amount is zero
    error KipuBank_ZeroAmount();
    
    /// @notice Error when price is zero
    error KipuBank_ZeroPrice();
    
    /// @notice Error when amount is invalid
    error KipuBank_InvalidAmount();

    /*///////////////////////////////////
            Modifiers
    ///////////////////////////////////*/

    /// @notice Modifier to validate amount is not zero
    modifier validAmount(uint256 amount) {
        if (amount == 0) revert InvalidAmount();
        _;
    }

    /// @notice Modifier to check withdrawal limit
    modifier withinWithdrawalLimit(uint256 amount) {
        if (amount > WITHDRAWAL_LIMIT) revert WithdrawalLimitExceeded();
        _;
    }

    /// @notice Modifier to check sufficient balance in personal vault
    modifier sufficientBalance(address user, uint256 amount) {
        if (personalVaults[user] < amount) revert InsufficientFunds();
        _;
    }

    /// @notice Modifier to check sufficient ETH balance
    modifier sufficientBalanceETH(address user, uint256 amount) {
        if (balance[user].eth < amount) revert InsufficientFunds();
        _;
    }

    /// @notice Modifier to check sufficient USDC balance
    modifier sufficientBalanceUSDC(address user, uint256 amount) {
        if (balance[user].usdc < amount) revert InsufficientFunds();
        _;
    }

    /*///////////////////////////////////
            Functions
    ///////////////////////////////////*/

    /**
     * @notice Constructor to initialize the bank with limits and token addresses
     * @param withdrawalLimit Maximum withdrawal limit per transaction
     * @param bankCapacity Total capacity of the bank
     * @param _token USDC token address
     * @param _ethUsdOracle Chainlink ETH/USD price feed address
     */
    constructor(
        uint256 withdrawalLimit,
        uint256 bankCapacity,
        IERC20 _token,
        address _ethUsdOracle
    ) Ownable(msg.sender) {
        WITHDRAWAL_LIMIT = withdrawalLimit;
        BANK_CAPACITY = bankCapacity;
        USDC = _token;
        s_feeds = AggregatorV3Interface(_ethUsdOracle);
    }

    /**
     * @notice Update the Chainlink price feed address
     * @param _feed New price feed address
     * @dev Only callable by owner
     */
    function setFeeds(address _feed) external onlyOwner {
        s_feeds = AggregatorV3Interface(_feed);
        emit DonationsV2_ChainlinkFeedUpdated(_feed);
    }

    /**
     * @notice Get current ETH price in USDC
     * @return _precio Current ETH price
     */
    function precioethUscd() public view returns (uint256 _precio) {
        return uint256(chainlinkFeed());
    }

    /**
     * @notice Get latest ETH price from Chainlink feed
     * @return ethUSDPrice_ Current ETH price in USD
     * @dev Includes validation for price freshness and integrity
     */
    function chainlinkFeed() public view returns (uint256 ethUSDPrice_) {
        (, int256 ethUSDPrice,, uint256 updatedAt,) = s_feeds.latestRoundData();

        if (ethUSDPrice == 0) revert KipuBank_OracleCompromised();
        if (block.timestamp - updatedAt > ORACLE_HEARTBEAT) revert KipuBank_StalePrice();

        ethUSDPrice_ = uint256(ethUSDPrice);
        return ethUSDPrice_;
    }

    /**
     * @notice Convert ETH amount to USDC equivalent
     * @param _ethAmount Amount of ETH to convert
     * @return convertedAmount_ Equivalent amount in USDC
     */
    function convertEthInUSD(
        uint256 _ethAmount
    ) external view returns (uint256 convertedAmount_) {
        convertedAmount_ = (_ethAmount * chainlinkFeed()) / DECIMAL_FACTOR;
    }

    /**
     * @notice Convert USDC amount to ETH equivalent
     * @param _usdcAmount Amount of USDC to convert
     * @return ethAmount Equivalent amount in ETH
     * @dev Includes validation for zero amounts and prices
     */
    function convertUsdcToEth(
        uint256 _usdcAmount
    ) public view returns (uint256) {
        if(_usdcAmount == 0) revert KipuBank_ZeroAmount();
        
        uint256 price = chainlinkFeed();
        if(price == 0) revert KipuBank_ZeroPrice();
        
        uint256 ethAmount = (_usdcAmount * DECIMAL_FACTOR) / price;
        if(ethAmount <= 0) revert KipuBank_InvalidAmount();
        return ethAmount;
    }

    /**
     * @notice Universal deposit function for both ETH and USDC
     * @param _add Token address (address(0) for ETH, USDC address for USDC)
     * @param amount Amount to deposit
     * @dev Handles both ETH and USDC deposits with capacity checks
     */
    function deposit(address _add, uint256 amount) external payable {
        if (_add == address(0)) {
            // ETH deposit logic
            if (msg.value <= 0) revert InvalidAmount();
            if (totalDeposited + msg.value > BANK_CAPACITY)
                revert BankCapacityExceeded();

            unchecked {
                personalVaults[msg.sender] += msg.value;
                totalContractETH += msg.value;
                balance[msg.sender].eth += msg.value;
                balance[msg.sender].total += msg.value;
                totalDepositsCount++;
                totalDeposited += msg.value;
            }

            emit SuccessfulDepositEth(msg.sender, amount, true);
        } else {
            // USDC deposit logic
            if (amount < 0) revert InvalidAmount();
            
            uint256 Uscd_ETH = convertUsdcToEth(amount);
            
            if (totalDeposited + Uscd_ETH > BANK_CAPACITY)
                revert BankCapacityExceeded();

            bool success = USDC.transferFrom(msg.sender, address(this), amount);
            if (!success) revert InvalidAmount();
            
            unchecked {
                balance[msg.sender].usdc += amount;
                balance[msg.sender].total += Uscd_ETH;
                personalVaults[msg.sender] += Uscd_ETH;
                totalDepositsCount++;
                totalDeposited += Uscd_ETH;
            }
            emit SuccessfulDepositUsdc(msg.sender, amount, true);
        }
    }

    /**
     * @notice Fallback function to receive ETH
     * @dev Automatically processes ETH deposits when sent directly to contract
     */
    receive() external payable {
        if (msg.value == 0) revert InvalidAmount();
        if (totalDeposited + msg.value > BANK_CAPACITY)
            revert BankCapacityExceeded();

        unchecked {
            personalVaults[msg.sender] += msg.value;
            totalContractETH += msg.value;
            balance[msg.sender].eth += msg.value;
            balance[msg.sender].total += msg.value;
            totalDepositsCount++;
            totalDeposited += msg.value;
        }

        emit SuccessfulDepositEth(msg.sender, msg.value, true);
    }

    /**
     * @notice Withdraw ETH from the bank
     * @param amount Amount of ETH to withdraw
     * @dev Includes multiple security checks and balance validations
     */
    function withdrawETH(
        uint256 amount
    )
        external
        validAmount(amount)
        withinWithdrawalLimit(amount)
        sufficientBalanceETH(msg.sender, amount)
        sufficientBalance(msg.sender, amount)
    {
        unchecked {
            personalVaults[msg.sender] -= amount;
            totalContractETH -= amount;
            balance[msg.sender].eth -= amount;
            balance[msg.sender].total -= amount;
            totalDeposited -= amount;
            totalWithdrawalsCount++;
        }

        (bool success, ) = payable(msg.sender).call{value: amount}("");
        if (!success) revert TransferFailed();

        emit SuccessfulWithdrawal(msg.sender, amount);
    }

    /**
     * @notice Withdraw USDC from the bank
     * @param amount Amount of USDC to withdraw
     * @dev Converts USDC to ETH equivalent for validation
     */
    function withdrawUSDC(uint256 amount) external {
        uint256 Uscd_ETH = convertUsdcToEth(amount);
     
        if (!withdrawUSDC_CONV(amount, Uscd_ETH)) revert TransferFailed();

        emit SuccessfulWithdrawalUSDC(msg.sender, Uscd_ETH);
    }

    /**
     * @notice Internal function to process USDC withdrawals
     * @param amount Amount of USDC to withdraw
     * @param usdc ETH equivalent of USDC amount
     * @return success Whether the withdrawal was successful
     * @dev Handles balance updates and token transfer
     */
    function withdrawUSDC_CONV(
        uint256 amount,
        uint256 usdc
    )
        internal
        validAmount(usdc)
        withinWithdrawalLimit(usdc)
        sufficientBalanceUSDC(msg.sender, amount)
        returns (bool success)
    {
        unchecked {
            personalVaults[msg.sender] -= usdc;
            totalDeposited -= usdc;
            totalWithdrawalsCount++;
        }

        balance[msg.sender].usdc -= amount;
        balance[msg.sender].total -= usdc;

        return USDC.transfer(msg.sender, amount);
    }

    /**
     * @notice Get user's balance information
     * @return eth ETH balance
     * @return usdc USDC balance
     * @return total Total balance
     */
    function myBalanceS()
        external
        view
        returns (uint256 eth, uint256 usdc, uint256 total)
    {
        return (
            balance[msg.sender].eth,
            balance[msg.sender].usdc,
            balance[msg.sender].total
        );
    }

    /**
     * @notice Get available capacity in the bank
     * @return Available space for additional deposits
     */
    function availableCapacity() external view returns (uint256) {
        return BANK_CAPACITY - totalDeposited;
    }

    /**
     * @notice Get comprehensive bank statistics
     * @return withdrawalLimit Current withdrawal limit
     * @return maximumCapacity Bank maximum capacity
     * @return currentTotal Total deposited amount
     * @return availableSpace Available remaining space
     * @dev Only callable by owner
     */
    function bankStatistics()
        external
        view
        onlyOwner
        returns (
            uint256 withdrawalLimit,
            uint256 maximumCapacity,
            uint256 currentTotal,
            uint256 availableSpace
        )
    {
        return (
            WITHDRAWAL_LIMIT,
            BANK_CAPACITY,
            totalDeposited,
            BANK_CAPACITY - totalDeposited
        );
    }

    /**
     * @notice Get transaction statistics
     * @return totalDeposits Total number of deposits
     * @return totalWithdrawals Total number of withdrawals
     * @return totalTransactions Total number of transactions
     * @dev Only callable by owner
     */
    function transactionStatistics()
        external
        view
        onlyOwner
        returns (
            uint256 totalDeposits,
            uint256 totalWithdrawals,
            uint256 totalTransactions
        )
    {
        return (
            totalDepositsCount,
            totalWithdrawalsCount,
            totalDepositsCount + totalWithdrawalsCount
        );
    }
}