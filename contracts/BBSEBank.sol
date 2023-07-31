// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import "./BBSEToken.sol";
import "./ETHBBSEPriceFeedOracle.sol";
import "@openzeppelin/contracts/access/Ownable.sol";

contract BBSEBank is Ownable {
    // BBSE Token Contract instance
    BBSEToken private bbseTokenContract;

    // ETHBBSEPriceFeedOracle Contract instance
    ETHBBSEPriceFeedOracle private oracleContract;

    // Yearly return rate of the bank
    uint32 public yearlyReturnRate;

    // Seconds in a year
    uint32 public constant YEAR_SECONDS = 31536000;

    // Average block time (set to a large number in order to increase the paid interest i.e., BBSE tokens)
    uint32 public constant AVG_BLOCK_TIME = 10000000;

    // Minimum deposit amount (1 Ether, expressed in Wei)
    uint public constant MIN_DEPOSIT_AMOUNT = 10 ** 18;

    /* Min. Ratio (Collateral value / Loan value)
     * Example: To take a 1 ETH loan,
     * an asset worth of at least 1.5 ETH must be collateralized.
     */
    uint8 public constant COLLATERALIZATION_RATIO = 150;

    // 1% of every collateral is taken as fee
    uint8 public constant LOAN_FEE_RATE = 1;

    /* Interest earned per second for a minumum deposit amount.
     * Equals to the yearly return of the minimum deposit amount
     * divided by the number of seconds in a year.
     */
    uint public interestPerSecondForMinDeposit;

    /* The value of the total deposited ETH.
     * BBSEBank shouldn't be giving loans where requested amount + totalDepositAmount > contract's ETH balance.
     * E.g., if all depositors want to withdraw while no borrowers paid their loan back, then the bank contract
     * should still be able to pay.
     */
    uint public totalDepositAmount;

    // Represents an investor record
    struct Investor {
        bool hasActiveDeposit;
        uint amount;
        uint startTime;
    }

    // Address to investor mapping
    mapping(address => Investor) public investors;

    // Represents a borrower record
    // TODO: Create a Borrower struct with following values: hasActiveLoan, amount, collateral (uint)
    struct Borrower {
        bool hasActiveLoan;
        uint amount;
        uint collateral;
    }

    // Address to borrower mapping
    // TODO: Create a borrowers mapping
    mapping(address => Borrower) public borrowers;

    /**
     * @dev Checks whether the yearlyReturnRate value is between 1 and 100
     */
    modifier validRate(uint _rate) {
        require(
            _rate > 0 && _rate <= 100,
            "Yearly return rate must be between 1 and 100"
        );
        _;
    }

    /**
     * @dev Initializes the bbseTokenContract with the provided contract address.
     * Sets the yearly return rate for the bank.
     * Yearly return rate must be between 1 and 100.
     * Calculates and sets the interest earned per second for a minumum deposit amount
     * based on the yearly return rate.
     * @param _bbseTokenContract address of the deployed BBSEToken contract
     * @param _yearlyReturnRate yearly return rate of the bank
     * @param _oracleContract address of the deployed ETHBBSEPriceFeedOracle contract
     */
    // TODO: Use the required modifier to check the yearlyReturnRate value
    constructor(
        address _bbseTokenContract,
        uint32 _yearlyReturnRate,
        address _oracleContract
    ) public validRate(_yearlyReturnRate) {
        bbseTokenContract = BBSEToken(_bbseTokenContract);
        oracleContract = ETHBBSEPriceFeedOracle(_oracleContract);
        yearlyReturnRate = _yearlyReturnRate;
        // Calculate interest per second for min deposit (1 Ether)
        interestPerSecondForMinDeposit =
            ((MIN_DEPOSIT_AMOUNT * yearlyReturnRate) / 100) /
            YEAR_SECONDS;
    }

    /**
     * @dev Initializes the respective investor object in investors mapping for the caller of the function.
     * Sets the amount to message value and starts the deposit time (hint: use block number as the start time).
     * Minimum deposit amount is 1 Ether (be careful about decimals!)
     * Investor can't have an already active deposit.
     */
    function deposit() public payable {
        require(
            msg.value >= MIN_DEPOSIT_AMOUNT,
            "Minimum deposit amount is 1 Ether"
        );
        require(
            investors[msg.sender].hasActiveDeposit != true,
            "Account can't have multiple active deposits"
        );

        // Updates total deposited amount
        // TODO: Update total deposit
        totalDepositAmount += msg.value;

        investors[msg.sender].amount = msg.value;
        investors[msg.sender].hasActiveDeposit = true;
        investors[msg.sender].startTime = block.number;
    }

    /**
     * @dev Calculates the interest to be paid out based
     * on the deposit amount and duration.
     * Transfers back the deposited amount in Ether.
     * Mints BBSE tokens to investor to pay the interest (1 token = 1 interest).
     * Resets the respective investor object in investors mapping.
     * Investor must have an active deposit.
     */
    function withdraw() public {
        require(
            investors[msg.sender].hasActiveDeposit == true,
            "Account must have an active deposit to withdraw"
        );
        Investor storage investor = investors[msg.sender];
        uint depositedAmount = investor.amount;
        uint depositDuration = (block.number - investor.startTime) *
            AVG_BLOCK_TIME;

        // Updates total deposited amount
        // TODO: Update total deposit
        totalDepositAmount -= investor.amount;

        // Calculate interest per second
        uint interestPerSecond = interestPerSecondForMinDeposit *
            (depositedAmount / MIN_DEPOSIT_AMOUNT);
        uint interest = interestPerSecond * depositDuration;

        // Reset the investor object
        investor.amount = 0;
        investor.hasActiveDeposit = false;
        investor.startTime = 0;

        // Send back deposited Ether to investor
        payable(msg.sender).transfer(depositedAmount);
        // Mint BBSE Tokens to investor, to pay out the interest
        bbseTokenContract.mint(msg.sender, interest);
    }

    /*
     * @dev Updates the value of the yearly return rate.
     * Only callable by the owner of the BBSEBank contract.
     * Yearly return rate must be between 1 and 100.
     * @param _yearlyReturnRate new yearly return rate
     */
    // TODO: Implement the updateYearlyReturnRate function (use the respective function modifier from Ownable)
    // TODO: Use the required modifier to check the yearlyReturnRate value

    function updateYearlyReturnRate(
        uint32 newRate
    ) public onlyOwner validRate(newRate) {
        yearlyReturnRate = newRate;
    }

    modifier cantHaveMultipleLoans() {
        require(
            !borrowers[msg.sender].hasActiveLoan,
            "Account can't have multiple active loans"
        );
        _;
    }

    /**
     * @dev Collaterize BBSE Token to borrow ETH.
     * A borrower can't have more than one active loan.
     * ETH amount to be borrowed + totalDepositAmount, must be existing in the contract balance.
     * @param amount the amount of ETH loan request (expressed in Wei)
     */
    function borrow(uint amount) public cantHaveMultipleLoans {
        // TODO: Check whether the borrower has an already active loan
        require(
            (amount + totalDepositAmount) <= address(this).balance,
            "The bank can't lend this amount right now"
        );

        // Get the latest price feed rate for ETH/BBSE from the price feed oracle
        // TODO: Uncomment
        uint priceFeedRate = oracleContract.getRate();

        // TODO: Calculate the collateral value and store it in uint collateral
        uint collateral = ((amount * COLLATERALIZATION_RATIO) / 100) *
            priceFeedRate;

        /* Try to transfer BBSE tokens from msg.sender (i.e. borrower) to BBSEBank.
         *  msg.sender must set an allowance to BBSEBank first, since BBSEBank
         *  needs to transfer the tokens from msg.sender to itself
         */
        // TODO: Uncomment
        require(
            bbseTokenContract.transferFrom(
                msg.sender,
                address(this),
                collateral
            ),
            "BBSEBank can't receive your tokens"
        );

        // TODO: Initialize the borrower in borrowers mapping
        borrowers[msg.sender].hasActiveLoan = true;
        borrowers[msg.sender].amount = amount;
        borrowers[msg.sender].collateral = collateral;

        // TODO: Transfer the requested amount to the borrower
        payable(msg.sender).transfer(amount);
    }

    /**
     * @dev Pays the borrowed loan.
     * Borrower receives back the collateral - fee BBSE tokens.
     * Borrower must have an active loan.
     * Borrower must send the exact ETH amount borrowed.
     */
    modifier hasActiveLoan() {
        require(
            borrowers[msg.sender].hasActiveLoan,
            "Account must have an active loan to pay back"
        );
        _;
    }

    function payLoan() public payable hasActiveLoan {
        // TODO: Check whether the borrower (i.e. function caller) has an active loan
        // TODO: Check whether the amount paid back is equal to the loan amount
        require(
            msg.value == borrowers[msg.sender].amount,
            "The paid amount must match the borrowed amount"
        );

        // TODO: Uncomment
        uint fee = (borrowers[msg.sender].collateral * LOAN_FEE_RATE) / 100;

        // TODO: Transfer back the BBSE tokens after the fee is cut to borrower
        bbseTokenContract.transfer(
            msg.sender,
            borrowers[msg.sender].collateral - fee
        );

        /* TODO: Reset the respective borrower object in investors mapping
         *        You can set the amount and collateral to 0
         */
        borrowers[msg.sender].amount = 0;
        borrowers[msg.sender].hasActiveLoan = false;
        borrowers[msg.sender].collateral = 0;
    }

    /**
     * @dev Called every time Ether is sent to the contract.
     * Required to fund the contract.
     */
    receive() external payable {}
}
