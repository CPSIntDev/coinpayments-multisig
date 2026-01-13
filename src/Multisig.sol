// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import {IERC20} from "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import {
    ReentrancyGuard
} from "@openzeppelin/contracts/utils/ReentrancyGuard.sol";

/**
 * @title USDTMultisig
 * @notice A multisig wallet for managing ERC20 USDT transfers
 * @dev Requires threshold signatures to execute transactions
 * @dev Auto-executes when threshold is reached (no separate execute call needed)
 * @dev Submitter automatically approves their own transaction
 * @dev Uses low-level call for legacy USDT compatibility (doesn't rely on return value)
 */
contract USDTMultisig is ReentrancyGuard {
    // Events
    event Deposit(address indexed sender, uint256 amount);
    event TransactionSubmitted(
        uint256 indexed txId,
        address indexed to,
        uint256 amount
    );
    event TransactionApproved(uint256 indexed txId, address indexed owner);
    event TransactionRevoked(uint256 indexed txId, address indexed owner);
    event TransactionExecuted(uint256 indexed txId);
    event TransactionCancelled(uint256 indexed txId);
    event OwnerAdded(address indexed owner);
    event OwnerRemoved(address indexed owner);
    event ThresholdChanged(uint256 newThreshold);

    // Errors
    error NotOwner();
    error TransactionNotFound();
    error TransactionAlreadyExecuted();
    error TransactionAlreadyApproved();
    error TransactionNotApproved();
    error InsufficientApprovals();
    error InvalidThreshold();
    error InvalidOwner();
    error OwnerAlreadyExists();
    error OwnerDoesNotExist();
    error InsufficientBalance();
    error ZeroAddress();
    error ZeroAmount();
    error TransactionNotExpired();

    // Constants
    uint256 public constant EXPIRATION_PERIOD = 1 days;

    // Transaction structure
    struct Transaction {
        address to;
        uint256 amount;
        bool executed;
        uint256 approvalCount;
        uint256 createdAt;
    }

    // State variables
    IERC20 public immutable usdt;
    address[] public owners;
    mapping(address => bool) public isOwner;
    uint256 public threshold;

    Transaction[] public transactions;
    // txId => owner => approved
    mapping(uint256 => mapping(address => bool)) public approvals;

    // Modifiers
    modifier onlyOwner() {
        if (!isOwner[msg.sender]) revert NotOwner();
        _;
    }

    modifier txExists(uint256 _txId) {
        if (_txId >= transactions.length) revert TransactionNotFound();
        _;
    }

    modifier notExecuted(uint256 _txId) {
        if (transactions[_txId].executed) revert TransactionAlreadyExecuted();
        _;
    }

    /**
     * @notice Constructor
     * @param _usdt Address of the USDT token contract
     * @param _owners Array of initial owner addresses
     * @param _threshold Number of required approvals
     */
    constructor(address _usdt, address[] memory _owners, uint256 _threshold) {
        if (_usdt == address(0)) revert ZeroAddress();
        if (_owners.length == 0) revert InvalidOwner();
        if (_threshold == 0 || _threshold > _owners.length)
            revert InvalidThreshold();

        usdt = IERC20(_usdt);

        for (uint256 i = 0; i < _owners.length; i++) {
            address owner = _owners[i];
            if (owner == address(0)) revert ZeroAddress();
            if (isOwner[owner]) revert OwnerAlreadyExists();

            isOwner[owner] = true;
            owners.push(owner);
        }

        threshold = _threshold;
    }

    /**
     * @notice Submit a new transaction proposal
     * @dev Automatically approves for the submitter
     * @dev Auto-executes if threshold is 1
     * @param _to Recipient address
     * @param _amount Amount of USDT to transfer
     * @return txId The transaction ID
     */
    function submitTransaction(
        address _to,
        uint256 _amount
    ) external onlyOwner nonReentrant returns (uint256 txId) {
        if (_to == address(0)) revert ZeroAddress();
        if (_amount == 0) revert ZeroAmount();

        txId = transactions.length;

        transactions.push(
            Transaction({
                to: _to,
                amount: _amount,
                executed: false,
                approvalCount: 1, // Start with 1 (submitter's approval)
                createdAt: block.timestamp
            })
        );

        // Auto-approve for submitter
        approvals[txId][msg.sender] = true;

        emit TransactionSubmitted(txId, _to, _amount);
        emit TransactionApproved(txId, msg.sender);

        // Auto-execute if threshold reached (e.g., threshold = 1)
        if (transactions[txId].approvalCount >= threshold) {
            _executeTransaction(txId);
        }
    }

    /**
     * @notice Approve a pending transaction
     * @dev Auto-executes if threshold is reached after this approval
     * @param _txId Transaction ID to approve
     */
    function approveTransaction(
        uint256 _txId
    ) external onlyOwner txExists(_txId) notExecuted(_txId) nonReentrant {
        if (approvals[_txId][msg.sender]) revert TransactionAlreadyApproved();

        approvals[_txId][msg.sender] = true;
        transactions[_txId].approvalCount++;

        emit TransactionApproved(_txId, msg.sender);

        // Auto-execute if threshold reached
        if (transactions[_txId].approvalCount >= threshold) {
            _executeTransaction(_txId);
        }
    }

    /**
     * @notice Revoke approval for a transaction
     * @param _txId Transaction ID to revoke
     */
    function revokeApproval(
        uint256 _txId
    ) external onlyOwner txExists(_txId) notExecuted(_txId) {
        if (!approvals[_txId][msg.sender]) revert TransactionNotApproved();

        approvals[_txId][msg.sender] = false;
        transactions[_txId].approvalCount--;

        emit TransactionRevoked(_txId, msg.sender);

        // Cancel transaction if no approvals remain
        if (transactions[_txId].approvalCount == 0) {
            transactions[_txId].executed = true; // Mark as executed to prevent further actions
            emit TransactionCancelled(_txId);
        }
    }

    /**
     * @notice Internal function to execute a transaction
     * @dev Called automatically when threshold is reached
     * @param _txId Transaction ID to execute
     */
    function _executeTransaction(uint256 _txId) internal {
        Transaction storage txn = transactions[_txId];

        uint256 balanceBefore = usdt.balanceOf(address(this));
        if (balanceBefore < txn.amount) revert InsufficientBalance();

        txn.executed = true;

        // Use low-level call for legacy USDT
        // Note: Old TetherToken returns false even on success, so we verify via balance change
        uint256 recipientBefore = usdt.balanceOf(txn.to);
        bool isSelfTransfer = txn.to == address(this);

        (bool success, ) = address(usdt).call(
            abi.encodeWithSelector(IERC20.transfer.selector, txn.to, txn.amount)
        );

        // Verify transfer succeeded by checking balance changes
        require(success, "Transfer call failed");

        // For self-transfers, balance stays the same; for others, recipient balance increases
        if (!isSelfTransfer) {
            require(
                usdt.balanceOf(txn.to) >= recipientBefore + txn.amount,
                "Transfer failed: recipient balance not updated"
            );
        }

        emit TransactionExecuted(_txId);
    }

    /**
     * @notice Get the number of owners
     * @return Number of owners
     */
    function getOwnerCount() external view returns (uint256) {
        return owners.length;
    }

    /**
     * @notice Get all owners
     * @return Array of owner addresses
     */
    function getOwners() external view returns (address[] memory) {
        return owners;
    }

    /**
     * @notice Get transaction count
     * @return Number of transactions
     */
    function getTransactionCount() external view returns (uint256) {
        return transactions.length;
    }

    /**
     * @notice Get transaction details
     * @param _txId Transaction ID
     * @return to Recipient address
     * @return amount Transfer amount
     * @return executed Whether executed
     * @return approvalCount Number of approvals
     * @return createdAt Timestamp when transaction was created
     */
    function getTransaction(
        uint256 _txId
    )
        external
        view
        txExists(_txId)
        returns (
            address to,
            uint256 amount,
            bool executed,
            uint256 approvalCount,
            uint256 createdAt
        )
    {
        Transaction storage txn = transactions[_txId];
        return (
            txn.to,
            txn.amount,
            txn.executed,
            txn.approvalCount,
            txn.createdAt
        );
    }

    /**
     * @notice Check if a transaction is expired
     * @param _txId Transaction ID
     * @return Whether the transaction is expired
     */
    function isExpired(
        uint256 _txId
    ) public view txExists(_txId) returns (bool) {
        Transaction storage txn = transactions[_txId];
        return
            !txn.executed &&
            block.timestamp > txn.createdAt + EXPIRATION_PERIOD;
    }

    /**
     * @notice Cancel an expired transaction
     * @dev Any owner can cancel an expired transaction
     * @param _txId Transaction ID to cancel
     */
    function cancelExpiredTransaction(
        uint256 _txId
    ) external onlyOwner txExists(_txId) notExecuted(_txId) {
        if (!isExpired(_txId)) revert TransactionNotExpired();

        transactions[_txId].executed = true; // Mark as executed to prevent further actions
        emit TransactionCancelled(_txId);
    }

    /**
     * @notice Check if a transaction is approved by an owner
     * @param _txId Transaction ID
     * @param _owner Owner address
     * @return Whether approved
     */
    function isApproved(
        uint256 _txId,
        address _owner
    ) external view txExists(_txId) returns (bool) {
        return approvals[_txId][_owner];
    }

    /**
     * @notice Get the USDT balance of this contract
     * @return USDT balance
     */
    function getBalance() external view returns (uint256) {
        return usdt.balanceOf(address(this));
    }
}
