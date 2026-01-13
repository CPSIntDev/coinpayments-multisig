// SPDX-License-Identifier: MIT
pragma solidity >=0.4.16 ^0.8.20;

// lib/openzeppelin-contracts/contracts/token/ERC20/IERC20.sol

// OpenZeppelin Contracts (last updated v5.4.0) (token/ERC20/IERC20.sol)

/**
 * @dev Interface of the ERC-20 standard as defined in the ERC.
 */
interface IERC20 {
    /**
     * @dev Emitted when `value` tokens are moved from one account (`from`) to
     * another (`to`).
     *
     * Note that `value` may be zero.
     */
    event Transfer(address indexed from, address indexed to, uint256 value);

    /**
     * @dev Emitted when the allowance of a `spender` for an `owner` is set by
     * a call to {approve}. `value` is the new allowance.
     */
    event Approval(address indexed owner, address indexed spender, uint256 value);

    /**
     * @dev Returns the value of tokens in existence.
     */
    function totalSupply() external view returns (uint256);

    /**
     * @dev Returns the value of tokens owned by `account`.
     */
    function balanceOf(address account) external view returns (uint256);

    /**
     * @dev Moves a `value` amount of tokens from the caller's account to `to`.
     *
     * Returns a boolean value indicating whether the operation succeeded.
     *
     * Emits a {Transfer} event.
     */
    function transfer(address to, uint256 value) external returns (bool);

    /**
     * @dev Returns the remaining number of tokens that `spender` will be
     * allowed to spend on behalf of `owner` through {transferFrom}. This is
     * zero by default.
     *
     * This value changes when {approve} or {transferFrom} are called.
     */
    function allowance(address owner, address spender) external view returns (uint256);

    /**
     * @dev Sets a `value` amount of tokens as the allowance of `spender` over the
     * caller's tokens.
     *
     * Returns a boolean value indicating whether the operation succeeded.
     *
     * IMPORTANT: Beware that changing an allowance with this method brings the risk
     * that someone may use both the old and the new allowance by unfortunate
     * transaction ordering. One possible solution to mitigate this race
     * condition is to first reduce the spender's allowance to 0 and set the
     * desired value afterwards:
     * https://github.com/ethereum/EIPs/issues/20#issuecomment-263524729
     *
     * Emits an {Approval} event.
     */
    function approve(address spender, uint256 value) external returns (bool);

    /**
     * @dev Moves a `value` amount of tokens from `from` to `to` using the
     * allowance mechanism. `value` is then deducted from the caller's
     * allowance.
     *
     * Returns a boolean value indicating whether the operation succeeded.
     *
     * Emits a {Transfer} event.
     */
    function transferFrom(address from, address to, uint256 value) external returns (bool);
}

// lib/openzeppelin-contracts/contracts/utils/StorageSlot.sol

// OpenZeppelin Contracts (last updated v5.1.0) (utils/StorageSlot.sol)
// This file was procedurally generated from scripts/generate/templates/StorageSlot.js.

/**
 * @dev Library for reading and writing primitive types to specific storage slots.
 *
 * Storage slots are often used to avoid storage conflict when dealing with upgradeable contracts.
 * This library helps with reading and writing to such slots without the need for inline assembly.
 *
 * The functions in this library return Slot structs that contain a `value` member that can be used to read or write.
 *
 * Example usage to set ERC-1967 implementation slot:
 * ```solidity
 * contract ERC1967 {
 *     // Define the slot. Alternatively, use the SlotDerivation library to derive the slot.
 *     bytes32 internal constant _IMPLEMENTATION_SLOT = 0x360894a13ba1a3210667c828492db98dca3e2076cc3735a920a3ca505d382bbc;
 *
 *     function _getImplementation() internal view returns (address) {
 *         return StorageSlot.getAddressSlot(_IMPLEMENTATION_SLOT).value;
 *     }
 *
 *     function _setImplementation(address newImplementation) internal {
 *         require(newImplementation.code.length > 0);
 *         StorageSlot.getAddressSlot(_IMPLEMENTATION_SLOT).value = newImplementation;
 *     }
 * }
 * ```
 *
 * TIP: Consider using this library along with {SlotDerivation}.
 */
library StorageSlot {
    struct AddressSlot {
        address value;
    }

    struct BooleanSlot {
        bool value;
    }

    struct Bytes32Slot {
        bytes32 value;
    }

    struct Uint256Slot {
        uint256 value;
    }

    struct Int256Slot {
        int256 value;
    }

    struct StringSlot {
        string value;
    }

    struct BytesSlot {
        bytes value;
    }

    /**
     * @dev Returns an `AddressSlot` with member `value` located at `slot`.
     */
    function getAddressSlot(bytes32 slot) internal pure returns (AddressSlot storage r) {
        assembly ("memory-safe") {
            r.slot := slot
        }
    }

    /**
     * @dev Returns a `BooleanSlot` with member `value` located at `slot`.
     */
    function getBooleanSlot(bytes32 slot) internal pure returns (BooleanSlot storage r) {
        assembly ("memory-safe") {
            r.slot := slot
        }
    }

    /**
     * @dev Returns a `Bytes32Slot` with member `value` located at `slot`.
     */
    function getBytes32Slot(bytes32 slot) internal pure returns (Bytes32Slot storage r) {
        assembly ("memory-safe") {
            r.slot := slot
        }
    }

    /**
     * @dev Returns a `Uint256Slot` with member `value` located at `slot`.
     */
    function getUint256Slot(bytes32 slot) internal pure returns (Uint256Slot storage r) {
        assembly ("memory-safe") {
            r.slot := slot
        }
    }

    /**
     * @dev Returns a `Int256Slot` with member `value` located at `slot`.
     */
    function getInt256Slot(bytes32 slot) internal pure returns (Int256Slot storage r) {
        assembly ("memory-safe") {
            r.slot := slot
        }
    }

    /**
     * @dev Returns a `StringSlot` with member `value` located at `slot`.
     */
    function getStringSlot(bytes32 slot) internal pure returns (StringSlot storage r) {
        assembly ("memory-safe") {
            r.slot := slot
        }
    }

    /**
     * @dev Returns an `StringSlot` representation of the string storage pointer `store`.
     */
    function getStringSlot(string storage store) internal pure returns (StringSlot storage r) {
        assembly ("memory-safe") {
            r.slot := store.slot
        }
    }

    /**
     * @dev Returns a `BytesSlot` with member `value` located at `slot`.
     */
    function getBytesSlot(bytes32 slot) internal pure returns (BytesSlot storage r) {
        assembly ("memory-safe") {
            r.slot := slot
        }
    }

    /**
     * @dev Returns an `BytesSlot` representation of the bytes storage pointer `store`.
     */
    function getBytesSlot(bytes storage store) internal pure returns (BytesSlot storage r) {
        assembly ("memory-safe") {
            r.slot := store.slot
        }
    }
}

// lib/openzeppelin-contracts/contracts/utils/ReentrancyGuard.sol

// OpenZeppelin Contracts (last updated v5.5.0) (utils/ReentrancyGuard.sol)

/**
 * @dev Contract module that helps prevent reentrant calls to a function.
 *
 * Inheriting from `ReentrancyGuard` will make the {nonReentrant} modifier
 * available, which can be applied to functions to make sure there are no nested
 * (reentrant) calls to them.
 *
 * Note that because there is a single `nonReentrant` guard, functions marked as
 * `nonReentrant` may not call one another. This can be worked around by making
 * those functions `private`, and then adding `external` `nonReentrant` entry
 * points to them.
 *
 * TIP: If EIP-1153 (transient storage) is available on the chain you're deploying at,
 * consider using {ReentrancyGuardTransient} instead.
 *
 * TIP: If you would like to learn more about reentrancy and alternative ways
 * to protect against it, check out our blog post
 * https://blog.openzeppelin.com/reentrancy-after-istanbul/[Reentrancy After Istanbul].
 *
 * IMPORTANT: Deprecated. This storage-based reentrancy guard will be removed and replaced
 * by the {ReentrancyGuardTransient} variant in v6.0.
 *
 * @custom:stateless
 */
abstract contract ReentrancyGuard {
    using StorageSlot for bytes32;

    // keccak256(abi.encode(uint256(keccak256("openzeppelin.storage.ReentrancyGuard")) - 1)) & ~bytes32(uint256(0xff))
    bytes32 private constant REENTRANCY_GUARD_STORAGE =
        0x9b779b17422d0df92223018b32b4d1fa46e071723d6817e2486d003becc55f00;

    // Booleans are more expensive than uint256 or any type that takes up a full
    // word because each write operation emits an extra SLOAD to first read the
    // slot's contents, replace the bits taken up by the boolean, and then write
    // back. This is the compiler's defense against contract upgrades and
    // pointer aliasing, and it cannot be disabled.

    // The values being non-zero value makes deployment a bit more expensive,
    // but in exchange the refund on every call to nonReentrant will be lower in
    // amount. Since refunds are capped to a percentage of the total
    // transaction's gas, it is best to keep them low in cases like this one, to
    // increase the likelihood of the full refund coming into effect.
    uint256 private constant NOT_ENTERED = 1;
    uint256 private constant ENTERED = 2;

    /**
     * @dev Unauthorized reentrant call.
     */
    error ReentrancyGuardReentrantCall();

    constructor() {
        _reentrancyGuardStorageSlot().getUint256Slot().value = NOT_ENTERED;
    }

    /**
     * @dev Prevents a contract from calling itself, directly or indirectly.
     * Calling a `nonReentrant` function from another `nonReentrant`
     * function is not supported. It is possible to prevent this from happening
     * by making the `nonReentrant` function external, and making it call a
     * `private` function that does the actual work.
     */
    modifier nonReentrant() {
        _nonReentrantBefore();
        _;
        _nonReentrantAfter();
    }

    /**
     * @dev A `view` only version of {nonReentrant}. Use to block view functions
     * from being called, preventing reading from inconsistent contract state.
     *
     * CAUTION: This is a "view" modifier and does not change the reentrancy
     * status. Use it only on view functions. For payable or non-payable functions,
     * use the standard {nonReentrant} modifier instead.
     */
    modifier nonReentrantView() {
        _nonReentrantBeforeView();
        _;
    }

    function _nonReentrantBeforeView() private view {
        if (_reentrancyGuardEntered()) {
            revert ReentrancyGuardReentrantCall();
        }
    }

    function _nonReentrantBefore() private {
        // On the first call to nonReentrant, _status will be NOT_ENTERED
        _nonReentrantBeforeView();

        // Any calls to nonReentrant after this point will fail
        _reentrancyGuardStorageSlot().getUint256Slot().value = ENTERED;
    }

    function _nonReentrantAfter() private {
        // By storing the original value once again, a refund is triggered (see
        // https://eips.ethereum.org/EIPS/eip-2200)
        _reentrancyGuardStorageSlot().getUint256Slot().value = NOT_ENTERED;
    }

    /**
     * @dev Returns true if the reentrancy guard is currently set to "entered", which indicates there is a
     * `nonReentrant` function in the call stack.
     */
    function _reentrancyGuardEntered() internal view returns (bool) {
        return _reentrancyGuardStorageSlot().getUint256Slot().value == ENTERED;
    }

    function _reentrancyGuardStorageSlot() internal pure virtual returns (bytes32) {
        return REENTRANCY_GUARD_STORAGE;
    }
}

// src/Multisig.sol

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

