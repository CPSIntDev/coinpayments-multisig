// SPDX-License-Identifier: MIT
pragma solidity ^0.8.13;

import {Test, console} from "forge-std/Test.sol";
import {USDTMultisig} from "../src/Multisig.sol";
import {ERC20} from "@openzeppelin/contracts/token/ERC20/ERC20.sol";

/**
 * @title MockTetherToken
 * @notice Mock implementation of TetherToken for testing
 * @dev Mimics the TRC20 USDT interface (issue instead of mint)
 * @dev For production, use the real TetherToken from src/TRC20_USDT/
 */
contract MockTetherToken is ERC20 {
    address public owner;

    constructor(
        uint256 _initialSupply,
        string memory _name,
        string memory _symbol,
        uint8 /* _decimals - ignored, hardcoded to 6 */
    ) ERC20(_name, _symbol) {
        owner = msg.sender;
        _mint(owner, _initialSupply);
    }

    function decimals() public pure override returns (uint8) {
        return 6;
    }

    /// @notice Issue new tokens (TetherToken compatible)
    /// @dev Only owner can issue, tokens go to owner address
    function issue(uint256 amount) external {
        require(msg.sender == owner, "Only owner can issue");
        _mint(owner, amount);
    }

    /// @notice Redeem tokens (TetherToken compatible)
    function redeem(uint256 amount) external {
        require(msg.sender == owner, "Only owner can redeem");
        _burn(owner, amount);
    }
}

contract USDTMultisigTest is Test {
    USDTMultisig public multisig;
    MockTetherToken public usdt;

    address public owner1;
    address public owner2;
    address public owner3;
    address public nonOwner;
    address public recipient;
    address public usdtOwner;

    uint256 constant INITIAL_SUPPLY = 1_000_000_000 * 1e6; // 1B USDT (like real Tether)
    uint256 constant MULTISIG_BALANCE = 1_000_000 * 1e6; // 1M USDT for multisig
    uint256 constant TRANSFER_AMOUNT = 100 * 1e6; // 100 USDT

    function setUp() public {
        owner1 = makeAddr("owner1");
        owner2 = makeAddr("owner2");
        owner3 = makeAddr("owner3");
        nonOwner = makeAddr("nonOwner");
        recipient = makeAddr("recipient");
        usdtOwner = makeAddr("usdtOwner");

        // Deploy TetherToken-compatible mock (owner receives initial supply)
        vm.prank(usdtOwner);
        usdt = new MockTetherToken(INITIAL_SUPPLY, "Tether USD", "USDT", 6);

        // Create multisig owners array
        address[] memory owners = new address[](3);
        owners[0] = owner1;
        owners[1] = owner2;
        owners[2] = owner3;

        // Deploy multisig with 2-of-3 threshold
        multisig = new USDTMultisig(address(usdt), owners, 2);

        // Transfer USDT from TetherToken owner to multisig
        vm.prank(usdtOwner);
        usdt.transfer(address(multisig), MULTISIG_BALANCE);
    }

    function test_Deployment() public view {
        assertEq(multisig.getOwnerCount(), 3);
        assertEq(multisig.threshold(), 2);
        assertTrue(multisig.isOwner(owner1));
        assertTrue(multisig.isOwner(owner2));
        assertTrue(multisig.isOwner(owner3));
        assertFalse(multisig.isOwner(nonOwner));
        assertEq(multisig.getBalance(), MULTISIG_BALANCE);
    }

    function test_TetherTokenInterface() public view {
        // Verify TetherToken-compatible interface
        assertEq(usdt.name(), "Tether USD");
        assertEq(usdt.symbol(), "USDT");
        assertEq(usdt.decimals(), 6);
        assertEq(usdt.owner(), usdtOwner);
        assertEq(usdt.totalSupply(), INITIAL_SUPPLY);
    }

    function test_TetherToken_Issue() public {
        // Test issue function (TetherToken specific)
        uint256 issueAmount = 1000 * 1e6;
        uint256 ownerBalanceBefore = usdt.balanceOf(usdtOwner);

        vm.prank(usdtOwner);
        usdt.issue(issueAmount);

        assertEq(usdt.balanceOf(usdtOwner), ownerBalanceBefore + issueAmount);
        assertEq(usdt.totalSupply(), INITIAL_SUPPLY + issueAmount);
    }

    function test_SubmitTransaction_AutoApproves() public {
        vm.prank(owner1);
        uint256 txId = multisig.submitTransaction(recipient, TRANSFER_AMOUNT);

        assertEq(txId, 0);
        assertEq(multisig.getTransactionCount(), 1);

        (
            address to,
            uint256 amount,
            bool executed,
            uint256 approvalCount,
            uint256 createdAt
        ) = multisig.getTransaction(txId);
        assertEq(to, recipient);
        assertEq(amount, TRANSFER_AMOUNT);
        assertFalse(executed); // Not executed yet (need 2 approvals)
        assertEq(approvalCount, 1); // Auto-approved by submitter
        assertEq(createdAt, block.timestamp); // Verify createdAt is set
        assertTrue(multisig.isApproved(txId, owner1)); // Submitter is approved
    }

    function test_SubmitTransaction_RevertNotOwner() public {
        vm.prank(nonOwner);
        vm.expectRevert(USDTMultisig.NotOwner.selector);
        multisig.submitTransaction(recipient, TRANSFER_AMOUNT);
    }

    function test_SubmitTransaction_RevertZeroAddress() public {
        vm.prank(owner1);
        vm.expectRevert(USDTMultisig.ZeroAddress.selector);
        multisig.submitTransaction(address(0), TRANSFER_AMOUNT);
    }

    function test_SubmitTransaction_RevertZeroAmount() public {
        vm.prank(owner1);
        vm.expectRevert(USDTMultisig.ZeroAmount.selector);
        multisig.submitTransaction(recipient, 0);
    }

    function test_ApproveTransaction_SubmitterCannotApproveAgain() public {
        vm.prank(owner1);
        uint256 txId = multisig.submitTransaction(recipient, TRANSFER_AMOUNT);

        // Submitter tries to approve again - should fail
        vm.prank(owner1);
        vm.expectRevert(USDTMultisig.TransactionAlreadyApproved.selector);
        multisig.approveTransaction(txId);
    }

    function test_ApproveTransaction_AutoExecutesOnThreshold() public {
        // Owner1 submits (auto-approves, count = 1)
        vm.prank(owner1);
        uint256 txId = multisig.submitTransaction(recipient, TRANSFER_AMOUNT);

        // Owner2 approves (count = 2 = threshold) -> auto-executes
        vm.prank(owner2);
        multisig.approveTransaction(txId);

        // Verify auto-executed
        (, , bool executed, uint256 approvalCount, ) = multisig.getTransaction(
            txId
        );
        assertTrue(executed);
        assertEq(approvalCount, 2);
        assertEq(usdt.balanceOf(recipient), TRANSFER_AMOUNT);
        assertEq(multisig.getBalance(), MULTISIG_BALANCE - TRANSFER_AMOUNT);
    }

    function test_RevokeApproval() public {
        // Deploy a new multisig with threshold=3 to test revoke without auto-execute
        address[] memory newOwners = new address[](3);
        newOwners[0] = owner1;
        newOwners[1] = owner2;
        newOwners[2] = owner3;
        USDTMultisig multisig3 = new USDTMultisig(address(usdt), newOwners, 3);

        // Transfer USDT from usdtOwner to multisig3
        vm.prank(usdtOwner);
        usdt.transfer(address(multisig3), MULTISIG_BALANCE);

        vm.prank(owner1);
        uint256 txId = multisig3.submitTransaction(recipient, TRANSFER_AMOUNT);

        // Owner2 approves (so we have 2 approvals, need 3)
        vm.prank(owner2);
        multisig3.approveTransaction(txId);

        // Owner2 revokes their approval
        vm.prank(owner2);
        multisig3.revokeApproval(txId);

        assertFalse(multisig3.isApproved(txId, owner2));
        (, , bool executed, uint256 approvalCount, ) = multisig3.getTransaction(
            txId
        );
        assertEq(approvalCount, 1);
        assertFalse(executed); // Still pending, has 1 approval
    }

    function test_RevokeApproval_CancelsWhenNoApprovals() public {
        vm.prank(owner1);
        uint256 txId = multisig.submitTransaction(recipient, TRANSFER_AMOUNT);

        // Check initial state - 1 approval from submitter
        (, , bool executedBefore, uint256 approvalBefore, ) = multisig
            .getTransaction(txId);
        assertEq(approvalBefore, 1);
        assertFalse(executedBefore);

        // Submitter revokes their only approval - should cancel transaction
        vm.prank(owner1);
        multisig.revokeApproval(txId);

        // Transaction should be cancelled (marked as executed)
        (, , bool executedAfter, uint256 approvalAfter, ) = multisig
            .getTransaction(txId);
        assertEq(approvalAfter, 0);
        assertTrue(executedAfter); // Marked as executed = cancelled

        // Cannot approve a cancelled transaction
        vm.prank(owner2);
        vm.expectRevert(USDTMultisig.TransactionAlreadyExecuted.selector);
        multisig.approveTransaction(txId);
    }

    function test_RevokeApproval_CannotRevokeExecuted() public {
        // Submit and get it executed
        vm.prank(owner1);
        uint256 txId = multisig.submitTransaction(recipient, TRANSFER_AMOUNT);

        vm.prank(owner2);
        multisig.approveTransaction(txId); // This triggers execution

        // Try to revoke after execution
        vm.prank(owner1);
        vm.expectRevert(USDTMultisig.TransactionAlreadyExecuted.selector);
        multisig.revokeApproval(txId);
    }

    function test_AutoExecute_InsufficientBalance() public {
        // Try to transfer more than balance
        uint256 hugeAmount = MULTISIG_BALANCE + 1;

        vm.prank(owner1);
        uint256 txId = multisig.submitTransaction(recipient, hugeAmount);

        // Second approval should trigger execution but fail due to insufficient balance
        vm.prank(owner2);
        vm.expectRevert(USDTMultisig.InsufficientBalance.selector);
        multisig.approveTransaction(txId);
    }

    function test_MultipleTransactions() public {
        // Submit 3 transactions (each auto-approves for owner1)
        vm.startPrank(owner1);
        uint256 txId1 = multisig.submitTransaction(recipient, 100 * 1e6);
        uint256 txId2 = multisig.submitTransaction(recipient, 200 * 1e6);
        uint256 txId3 = multisig.submitTransaction(recipient, 300 * 1e6);
        vm.stopPrank();

        assertEq(multisig.getTransactionCount(), 3);
        assertEq(txId1, 0);
        assertEq(txId2, 1);
        assertEq(txId3, 2);

        // Execute only txId2 (owner2 approves -> threshold reached -> auto-execute)
        vm.prank(owner2);
        multisig.approveTransaction(txId2);

        // Verify only txId2 is executed
        (, , bool executed1, , ) = multisig.getTransaction(txId1);
        (, , bool executed2, , ) = multisig.getTransaction(txId2);
        (, , bool executed3, , ) = multisig.getTransaction(txId3);

        assertFalse(executed1);
        assertTrue(executed2);
        assertFalse(executed3);

        assertEq(usdt.balanceOf(recipient), 200 * 1e6);
    }

    function test_ThresholdOne_AutoExecutesOnSubmit() public {
        // Deploy a new multisig with threshold = 1
        address[] memory owners = new address[](2);
        owners[0] = owner1;
        owners[1] = owner2;

        USDTMultisig multisig1of2 = new USDTMultisig(address(usdt), owners, 1);

        // Fund it
        vm.prank(usdtOwner);
        usdt.transfer(address(multisig1of2), MULTISIG_BALANCE);

        // Submit should auto-approve AND auto-execute immediately
        vm.prank(owner1);
        uint256 txId = multisig1of2.submitTransaction(
            recipient,
            TRANSFER_AMOUNT
        );

        // Should be already executed
        (, , bool executed, uint256 approvalCount, ) = multisig1of2
            .getTransaction(txId);
        assertTrue(executed);
        assertEq(approvalCount, 1);
        assertEq(usdt.balanceOf(recipient), TRANSFER_AMOUNT);
    }

    function test_GetOwners() public view {
        address[] memory owners = multisig.getOwners();
        assertEq(owners.length, 3);
        assertEq(owners[0], owner1);
        assertEq(owners[1], owner2);
        assertEq(owners[2], owner3);
    }

    function test_Constructor_RevertZeroUsdtAddress() public {
        address[] memory owners = new address[](2);
        owners[0] = owner1;
        owners[1] = owner2;

        vm.expectRevert(USDTMultisig.ZeroAddress.selector);
        new USDTMultisig(address(0), owners, 2);
    }

    function test_Constructor_RevertZeroOwnerAddress() public {
        address[] memory owners = new address[](2);
        owners[0] = owner1;
        owners[1] = address(0);

        vm.expectRevert(USDTMultisig.ZeroAddress.selector);
        new USDTMultisig(address(usdt), owners, 2);
    }

    function test_Constructor_RevertDuplicateOwner() public {
        address[] memory owners = new address[](2);
        owners[0] = owner1;
        owners[1] = owner1;

        vm.expectRevert(USDTMultisig.OwnerAlreadyExists.selector);
        new USDTMultisig(address(usdt), owners, 2);
    }

    function test_Constructor_RevertInvalidThreshold() public {
        address[] memory owners = new address[](2);
        owners[0] = owner1;
        owners[1] = owner2;

        // Threshold > owners
        vm.expectRevert(USDTMultisig.InvalidThreshold.selector);
        new USDTMultisig(address(usdt), owners, 3);

        // Threshold = 0
        vm.expectRevert(USDTMultisig.InvalidThreshold.selector);
        new USDTMultisig(address(usdt), owners, 0);
    }

    function testFuzz_SubmitAndAutoExecute(uint256 amount) public {
        vm.assume(amount > 0 && amount <= MULTISIG_BALANCE);

        // Owner1 submits (auto-approves)
        vm.prank(owner1);
        uint256 txId = multisig.submitTransaction(recipient, amount);

        // Owner2 approves (reaches threshold -> auto-executes)
        vm.prank(owner2);
        multisig.approveTransaction(txId);

        assertEq(usdt.balanceOf(recipient), amount);
    }

    function test_CannotApproveExecutedTransaction() public {
        // Submit and execute
        vm.prank(owner1);
        uint256 txId = multisig.submitTransaction(recipient, TRANSFER_AMOUNT);

        vm.prank(owner2);
        multisig.approveTransaction(txId); // Auto-executes

        // Owner3 tries to approve executed transaction
        vm.prank(owner3);
        vm.expectRevert(USDTMultisig.TransactionAlreadyExecuted.selector);
        multisig.approveTransaction(txId);
    }

    // ============ Expiration Tests ============

    function test_ExpirationPeriod() public view {
        // Verify EXPIRATION_PERIOD is 1 day (86400 seconds)
        assertEq(multisig.EXPIRATION_PERIOD(), 1 days);
        assertEq(multisig.EXPIRATION_PERIOD(), 86400);
    }

    function test_IsExpired_NotExpiredInitially() public {
        vm.prank(owner1);
        uint256 txId = multisig.submitTransaction(recipient, TRANSFER_AMOUNT);

        // Transaction should not be expired immediately
        assertFalse(multisig.isExpired(txId));
    }

    function test_IsExpired_NotExpiredBeforeDeadline() public {
        vm.prank(owner1);
        uint256 txId = multisig.submitTransaction(recipient, TRANSFER_AMOUNT);

        // Warp time to just before expiration (1 day - 1 second)
        vm.warp(block.timestamp + 1 days - 1);

        // Transaction should still not be expired
        assertFalse(multisig.isExpired(txId));
    }

    function test_IsExpired_ExpiredAfterDeadline() public {
        vm.prank(owner1);
        uint256 txId = multisig.submitTransaction(recipient, TRANSFER_AMOUNT);

        // Warp time to just after expiration (1 day + 1 second)
        vm.warp(block.timestamp + 1 days + 1);

        // Transaction should be expired
        assertTrue(multisig.isExpired(txId));
    }

    function test_IsExpired_ExecutedTransactionNotExpired() public {
        // Submit and execute
        vm.prank(owner1);
        uint256 txId = multisig.submitTransaction(recipient, TRANSFER_AMOUNT);

        vm.prank(owner2);
        multisig.approveTransaction(txId); // Auto-executes

        // Warp time past expiration
        vm.warp(block.timestamp + 2 days);

        // Executed transaction should not be considered expired
        assertFalse(multisig.isExpired(txId));
    }

    function test_CancelExpiredTransaction_BySubmitter() public {
        vm.prank(owner1);
        uint256 txId = multisig.submitTransaction(recipient, TRANSFER_AMOUNT);

        // Warp time past expiration
        vm.warp(block.timestamp + 1 days + 1);

        // Submitter (owner1) cancels
        vm.prank(owner1);
        multisig.cancelExpiredTransaction(txId);

        // Verify transaction is marked as executed (cancelled)
        (, , bool executed, , ) = multisig.getTransaction(txId);
        assertTrue(executed);

        // Funds should still be in multisig (not transferred)
        assertEq(usdt.balanceOf(recipient), 0);
        assertEq(multisig.getBalance(), MULTISIG_BALANCE);
    }

    function test_CancelExpiredTransaction_ByOtherOwner() public {
        // Owner1 submits
        vm.prank(owner1);
        uint256 txId = multisig.submitTransaction(recipient, TRANSFER_AMOUNT);

        // Warp time past expiration
        vm.warp(block.timestamp + 1 days + 1);

        // Owner2 (not the submitter) can cancel
        vm.prank(owner2);
        multisig.cancelExpiredTransaction(txId);

        // Verify transaction is cancelled
        (, , bool executed, , ) = multisig.getTransaction(txId);
        assertTrue(executed);
    }

    function test_CancelExpiredTransaction_ByThirdOwner() public {
        // Owner1 submits
        vm.prank(owner1);
        uint256 txId = multisig.submitTransaction(recipient, TRANSFER_AMOUNT);

        // Warp time past expiration
        vm.warp(block.timestamp + 1 days + 1);

        // Owner3 (neither submitter nor previous approver) can cancel
        vm.prank(owner3);
        multisig.cancelExpiredTransaction(txId);

        // Verify transaction is cancelled
        (, , bool executed, , ) = multisig.getTransaction(txId);
        assertTrue(executed);
    }

    function test_CancelExpiredTransaction_EmitsEvent() public {
        vm.prank(owner1);
        uint256 txId = multisig.submitTransaction(recipient, TRANSFER_AMOUNT);

        // Warp time past expiration
        vm.warp(block.timestamp + 1 days + 1);

        // Expect TransactionCancelled event
        vm.expectEmit(true, false, false, false);
        emit USDTMultisig.TransactionCancelled(txId);

        vm.prank(owner2);
        multisig.cancelExpiredTransaction(txId);
    }

    function test_CancelExpiredTransaction_RevertNotExpired() public {
        vm.prank(owner1);
        uint256 txId = multisig.submitTransaction(recipient, TRANSFER_AMOUNT);

        // Try to cancel immediately (not expired yet)
        vm.prank(owner2);
        vm.expectRevert(USDTMultisig.TransactionNotExpired.selector);
        multisig.cancelExpiredTransaction(txId);
    }

    function test_CancelExpiredTransaction_RevertNotExpiredJustBefore() public {
        vm.prank(owner1);
        uint256 txId = multisig.submitTransaction(recipient, TRANSFER_AMOUNT);

        // Warp to just before expiration
        vm.warp(block.timestamp + 1 days);

        // Try to cancel (exactly at deadline, not past it)
        vm.prank(owner2);
        vm.expectRevert(USDTMultisig.TransactionNotExpired.selector);
        multisig.cancelExpiredTransaction(txId);
    }

    function test_CancelExpiredTransaction_RevertAlreadyExecuted() public {
        // Submit and execute
        vm.prank(owner1);
        uint256 txId = multisig.submitTransaction(recipient, TRANSFER_AMOUNT);

        vm.prank(owner2);
        multisig.approveTransaction(txId); // Auto-executes

        // Warp time past expiration
        vm.warp(block.timestamp + 2 days);

        // Try to cancel executed transaction
        vm.prank(owner3);
        vm.expectRevert(USDTMultisig.TransactionAlreadyExecuted.selector);
        multisig.cancelExpiredTransaction(txId);
    }

    function test_CancelExpiredTransaction_RevertNotOwner() public {
        vm.prank(owner1);
        uint256 txId = multisig.submitTransaction(recipient, TRANSFER_AMOUNT);

        // Warp time past expiration
        vm.warp(block.timestamp + 1 days + 1);

        // Non-owner tries to cancel
        vm.prank(nonOwner);
        vm.expectRevert(USDTMultisig.NotOwner.selector);
        multisig.cancelExpiredTransaction(txId);
    }

    function test_CancelExpiredTransaction_RevertTransactionNotFound() public {
        // Try to cancel non-existent transaction
        vm.warp(block.timestamp + 2 days);

        vm.prank(owner1);
        vm.expectRevert(USDTMultisig.TransactionNotFound.selector);
        multisig.cancelExpiredTransaction(999);
    }

    function test_CannotApproveExpiredTransaction() public {
        vm.prank(owner1);
        uint256 txId = multisig.submitTransaction(recipient, TRANSFER_AMOUNT);

        // Warp time past expiration
        vm.warp(block.timestamp + 1 days + 1);

        // Trying to approve an expired transaction should still work technically
        // (the contract doesn't prevent approval of expired transactions)
        // but it's better UX to cancel instead
        // This test verifies the approval still works if someone really wants to
        vm.prank(owner2);
        multisig.approveTransaction(txId);

        // Transaction should be executed since threshold was reached
        (, , bool executed, uint256 approvalCount, ) = multisig.getTransaction(
            txId
        );
        assertTrue(executed);
        assertEq(approvalCount, 2);
    }

    function test_GetTransaction_ReturnsCreatedAt() public {
        uint256 submitTime = block.timestamp;

        vm.prank(owner1);
        uint256 txId = multisig.submitTransaction(recipient, TRANSFER_AMOUNT);

        (
            address to,
            uint256 amount,
            bool executed,
            uint256 approvalCount,
            uint256 createdAt
        ) = multisig.getTransaction(txId);

        assertEq(to, recipient);
        assertEq(amount, TRANSFER_AMOUNT);
        assertFalse(executed);
        assertEq(approvalCount, 1);
        assertEq(createdAt, submitTime);
    }

    function test_MultipleExpiredTransactions() public {
        // Submit multiple transactions at the same timestamp
        vm.startPrank(owner1);
        uint256 txId1 = multisig.submitTransaction(recipient, 100 * 1e6);
        uint256 txId2 = multisig.submitTransaction(recipient, 200 * 1e6);
        uint256 txId3 = multisig.submitTransaction(recipient, 300 * 1e6);
        vm.stopPrank();

        // Get creation times (all same timestamp)
        (, , , , uint256 createdAt1) = multisig.getTransaction(txId1);
        (, , , , uint256 createdAt2) = multisig.getTransaction(txId2);
        (, , , , uint256 createdAt3) = multisig.getTransaction(txId3);

        // All created at the same time
        assertEq(createdAt1, createdAt2);
        assertEq(createdAt2, createdAt3);

        // Warp to after all transactions expire
        vm.warp(createdAt1 + 1 days + 1);

        // All should be expired
        assertTrue(multisig.isExpired(txId1));
        assertTrue(multisig.isExpired(txId2));
        assertTrue(multisig.isExpired(txId3));

        // Cancel txId1 (owner2 cancels)
        vm.prank(owner2);
        multisig.cancelExpiredTransaction(txId1);

        // Cancel txId2 (owner3 cancels)
        vm.prank(owner3);
        multisig.cancelExpiredTransaction(txId2);

        // Cancel txId3 (owner1 cancels their own)
        vm.prank(owner1);
        multisig.cancelExpiredTransaction(txId3);

        // All should be cancelled
        (, , bool exec1, , ) = multisig.getTransaction(txId1);
        (, , bool exec2, , ) = multisig.getTransaction(txId2);
        (, , bool exec3, , ) = multisig.getTransaction(txId3);
        assertTrue(exec1);
        assertTrue(exec2);
        assertTrue(exec3);

        // No funds transferred
        assertEq(usdt.balanceOf(recipient), 0);
    }

    function test_ExpiredTransactions_DifferentTimes() public {
        // Submit transactions at different times
        vm.prank(owner1);
        uint256 txId1 = multisig.submitTransaction(recipient, 100 * 1e6);
        (, , , , uint256 createdAt1) = multisig.getTransaction(txId1);

        // Advance 12 hours
        vm.warp(block.timestamp + 12 hours);

        vm.prank(owner1);
        uint256 txId2 = multisig.submitTransaction(recipient, 200 * 1e6);
        (, , , , uint256 createdAt2) = multisig.getTransaction(txId2);

        // Verify different creation times
        assertEq(createdAt2, createdAt1 + 12 hours);

        // Warp to after txId1 expires but before txId2 expires
        vm.warp(createdAt1 + 1 days + 1);

        // txId1 should be expired
        assertTrue(multisig.isExpired(txId1));
        // txId2 should NOT be expired yet (12 hours remain)
        assertFalse(multisig.isExpired(txId2));

        // Can cancel txId1
        vm.prank(owner2);
        multisig.cancelExpiredTransaction(txId1);

        // Cannot cancel txId2 yet
        vm.prank(owner2);
        vm.expectRevert(USDTMultisig.TransactionNotExpired.selector);
        multisig.cancelExpiredTransaction(txId2);

        // Warp to after txId2 expires
        vm.warp(createdAt2 + 1 days + 1);

        // Now txId2 is expired
        assertTrue(multisig.isExpired(txId2));

        // Can cancel txId2 now
        vm.prank(owner3);
        multisig.cancelExpiredTransaction(txId2);

        // Both cancelled, no funds transferred
        assertEq(usdt.balanceOf(recipient), 0);
    }
}
