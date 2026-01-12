// SPDX-License-Identifier: MIT
pragma solidity ^0.8.13;

import {Test, console} from "forge-std/Test.sol";
import {ITetherToken} from "../src/interfaces/ITetherToken.sol";

/**
 * @title TetherToken Tests
 * @notice Comprehensive tests for the TRC20 USDT TetherToken contract
 * @dev Deploys TetherToken from compiled bytecode (Solidity 0.4.x)
 */
contract TetherTokenTest is Test {
    ITetherToken public usdt;

    address public owner;
    address public user1;
    address public user2;
    address public user3;

    uint256 constant INITIAL_SUPPLY = 1_000_000_000 * 1e6; // 1B USDT
    uint256 constant TRANSFER_AMOUNT = 1000 * 1e6; // 1000 USDT

    function setUp() public {
        owner = address(this);
        user1 = makeAddr("user1");
        user2 = makeAddr("user2");
        user3 = makeAddr("user3");

        // Deploy TetherToken from compiled bytecode
        // Constructor: TetherToken(uint _initialSupply, string _name, string _symbol, uint8 _decimals)
        bytes memory bytecode = vm.getCode("out-trc20/TetherToken.sol/TetherToken.json");
        bytes memory constructorArgs = abi.encode(
            INITIAL_SUPPLY,
            "Tether USD",
            "USDT",
            uint8(6)
        );
        
        address deployed;
        bytes memory creationCode = abi.encodePacked(bytecode, constructorArgs);
        assembly {
            deployed := create(0, add(creationCode, 0x20), mload(creationCode))
        }
        require(deployed != address(0), "TetherToken deployment failed");
        
        usdt = ITetherToken(deployed);
    }

    // ============================================
    // Deployment Tests
    // ============================================

    function test_Deployment() public view {
        assertEq(usdt.name(), "Tether USD");
        assertEq(usdt.symbol(), "USDT");
        assertEq(usdt.decimals(), 6);
        assertEq(usdt.totalSupply(), INITIAL_SUPPLY);
        assertEq(usdt.balanceOf(owner), INITIAL_SUPPLY);
        assertEq(usdt.owner(), owner);
    }

    function test_InitialSupplyToOwner() public view {
        assertEq(usdt.balanceOf(owner), INITIAL_SUPPLY);
        assertEq(usdt.balanceOf(user1), 0);
        assertEq(usdt.balanceOf(user2), 0);
    }

    // ============================================
    // Transfer Tests
    // ============================================

    function test_Transfer() public {
        // Note: StandardTokenWithFees.transfer doesn't return true explicitly
        // but the transfer still works
        usdt.transfer(user1, TRANSFER_AMOUNT);
        assertEq(usdt.balanceOf(user1), TRANSFER_AMOUNT);
        assertEq(usdt.balanceOf(owner), INITIAL_SUPPLY - TRANSFER_AMOUNT);
    }

    function test_Transfer_ToMultipleUsers() public {
        usdt.transfer(user1, 100 * 1e6);
        usdt.transfer(user2, 200 * 1e6);
        usdt.transfer(user3, 300 * 1e6);

        assertEq(usdt.balanceOf(user1), 100 * 1e6);
        assertEq(usdt.balanceOf(user2), 200 * 1e6);
        assertEq(usdt.balanceOf(user3), 300 * 1e6);
        assertEq(usdt.balanceOf(owner), INITIAL_SUPPLY - 600 * 1e6);
    }

    function test_Transfer_BetweenUsers() public {
        // Owner sends to user1
        usdt.transfer(user1, TRANSFER_AMOUNT);
        
        // User1 sends to user2
        vm.prank(user1);
        usdt.transfer(user2, 500 * 1e6);

        assertEq(usdt.balanceOf(user1), 500 * 1e6);
        assertEq(usdt.balanceOf(user2), 500 * 1e6);
    }

    function test_Transfer_RevertInsufficientBalance() public {
        vm.prank(user1);
        vm.expectRevert();
        usdt.transfer(user2, TRANSFER_AMOUNT);
    }

    function test_Transfer_ZeroAmount() public {
        // Note: Zero amount transfer works but StandardTokenWithFees doesn't return true
        usdt.transfer(user1, 0);
        assertEq(usdt.balanceOf(user1), 0);
    }

    // ============================================
    // Approval & TransferFrom Tests
    // ============================================

    function test_Approve() public {
        bool success = usdt.approve(user1, TRANSFER_AMOUNT);
        assertTrue(success);
        assertEq(usdt.allowance(owner, user1), TRANSFER_AMOUNT);
    }

    function test_TransferFrom() public {
        // Owner approves user1 to spend
        usdt.approve(user1, TRANSFER_AMOUNT);

        // User1 transfers from owner to user2
        vm.prank(user1);
        bool success = usdt.transferFrom(owner, user2, TRANSFER_AMOUNT);
        
        assertTrue(success);
        assertEq(usdt.balanceOf(user2), TRANSFER_AMOUNT);
        assertEq(usdt.balanceOf(owner), INITIAL_SUPPLY - TRANSFER_AMOUNT);
        assertEq(usdt.allowance(owner, user1), 0);
    }

    function test_TransferFrom_PartialAllowance() public {
        usdt.approve(user1, TRANSFER_AMOUNT);

        // Use only half the allowance
        vm.prank(user1);
        usdt.transferFrom(owner, user2, TRANSFER_AMOUNT / 2);

        assertEq(usdt.allowance(owner, user1), TRANSFER_AMOUNT / 2);
        assertEq(usdt.balanceOf(user2), TRANSFER_AMOUNT / 2);
    }

    function test_TransferFrom_RevertExceedsAllowance() public {
        usdt.approve(user1, TRANSFER_AMOUNT);

        vm.prank(user1);
        vm.expectRevert();
        usdt.transferFrom(owner, user2, TRANSFER_AMOUNT + 1);
    }

    function test_TransferFrom_RevertNoAllowance() public {
        vm.prank(user1);
        vm.expectRevert();
        usdt.transferFrom(owner, user2, TRANSFER_AMOUNT);
    }

    // ============================================
    // Issue & Redeem Tests (Owner only)
    // ============================================

    function test_Issue() public {
        uint256 issueAmount = 500_000 * 1e6;
        uint256 supplyBefore = usdt.totalSupply();
        uint256 ownerBalanceBefore = usdt.balanceOf(owner);

        usdt.issue(issueAmount);

        assertEq(usdt.totalSupply(), supplyBefore + issueAmount);
        assertEq(usdt.balanceOf(owner), ownerBalanceBefore + issueAmount);
    }

    function test_Issue_RevertNotOwner() public {
        vm.prank(user1);
        vm.expectRevert();
        usdt.issue(1000 * 1e6);
    }

    function test_Redeem() public {
        uint256 redeemAmount = 500_000 * 1e6;
        uint256 supplyBefore = usdt.totalSupply();
        uint256 ownerBalanceBefore = usdt.balanceOf(owner);

        usdt.redeem(redeemAmount);

        assertEq(usdt.totalSupply(), supplyBefore - redeemAmount);
        assertEq(usdt.balanceOf(owner), ownerBalanceBefore - redeemAmount);
    }

    function test_Redeem_RevertNotOwner() public {
        vm.prank(user1);
        vm.expectRevert();
        usdt.redeem(1000 * 1e6);
    }

    function test_Redeem_RevertInsufficientBalance() public {
        // Try to redeem more than owner has
        vm.expectRevert();
        usdt.redeem(INITIAL_SUPPLY + 1);
    }

    // ============================================
    // Pause Tests
    // ============================================

    function test_Pause() public {
        usdt.pause();
        assertTrue(usdt.paused());
    }

    function test_Pause_RevertNotOwner() public {
        vm.prank(user1);
        vm.expectRevert();
        usdt.pause();
    }

    function test_Unpause() public {
        usdt.pause();
        assertTrue(usdt.paused());

        usdt.unpause();
        assertFalse(usdt.paused());
    }

    function test_Transfer_RevertWhenPaused() public {
        usdt.pause();

        vm.expectRevert();
        usdt.transfer(user1, TRANSFER_AMOUNT);
    }

    function test_TransferFrom_RevertWhenPaused() public {
        usdt.approve(user1, TRANSFER_AMOUNT);
        usdt.pause();

        vm.prank(user1);
        vm.expectRevert();
        usdt.transferFrom(owner, user2, TRANSFER_AMOUNT);
    }

    function test_Approve_RevertWhenPaused() public {
        usdt.pause();

        vm.expectRevert();
        usdt.approve(user1, TRANSFER_AMOUNT);
    }

    // ============================================
    // BlackList Tests
    // ============================================

    function test_AddBlackList() public {
        assertFalse(usdt.isBlackListed(user1));
        
        usdt.addBlackList(user1);
        
        assertTrue(usdt.isBlackListed(user1));
    }

    function test_AddBlackList_RevertNotOwner() public {
        vm.prank(user1);
        vm.expectRevert();
        usdt.addBlackList(user2);
    }

    function test_RemoveBlackList() public {
        usdt.addBlackList(user1);
        assertTrue(usdt.isBlackListed(user1));

        usdt.removeBlackList(user1);
        assertFalse(usdt.isBlackListed(user1));
    }

    function test_Transfer_RevertWhenBlackListed() public {
        // Give user1 some tokens
        usdt.transfer(user1, TRANSFER_AMOUNT);
        
        // Blacklist user1
        usdt.addBlackList(user1);

        // User1 cannot transfer
        vm.prank(user1);
        vm.expectRevert();
        usdt.transfer(user2, 100 * 1e6);
    }

    function test_TransferFrom_RevertWhenSenderBlackListed() public {
        // Give user1 some tokens and approve user2 to spend
        usdt.transfer(user1, TRANSFER_AMOUNT);
        vm.prank(user1);
        usdt.approve(user2, TRANSFER_AMOUNT);

        // Blacklist user1 (the token holder)
        usdt.addBlackList(user1);

        // User2 cannot transfer from blacklisted user1
        vm.prank(user2);
        vm.expectRevert();
        usdt.transferFrom(user1, user3, 100 * 1e6);
    }

    function test_DestroyBlackFunds() public {
        // Give user1 some tokens
        usdt.transfer(user1, TRANSFER_AMOUNT);
        assertEq(usdt.balanceOf(user1), TRANSFER_AMOUNT);

        // Blacklist and destroy funds
        usdt.addBlackList(user1);
        
        uint256 supplyBefore = usdt.totalSupply();
        usdt.destroyBlackFunds(user1);

        assertEq(usdt.balanceOf(user1), 0);
        assertEq(usdt.totalSupply(), supplyBefore - TRANSFER_AMOUNT);
    }

    function test_DestroyBlackFunds_RevertNotBlackListed() public {
        usdt.transfer(user1, TRANSFER_AMOUNT);

        vm.expectRevert();
        usdt.destroyBlackFunds(user1);
    }

    function test_DestroyBlackFunds_RevertNotOwner() public {
        usdt.transfer(user1, TRANSFER_AMOUNT);
        usdt.addBlackList(user1);

        vm.prank(user2);
        vm.expectRevert();
        usdt.destroyBlackFunds(user1);
    }

    // ============================================
    // Fuzz Tests
    // ============================================

    function testFuzz_Transfer(uint256 amount) public {
        vm.assume(amount > 0 && amount <= INITIAL_SUPPLY);
        
        usdt.transfer(user1, amount);
        
        assertEq(usdt.balanceOf(user1), amount);
        assertEq(usdt.balanceOf(owner), INITIAL_SUPPLY - amount);
    }

    function testFuzz_Issue(uint256 amount) public {
        vm.assume(amount > 0 && amount < type(uint128).max);
        
        uint256 supplyBefore = usdt.totalSupply();
        usdt.issue(amount);
        
        assertEq(usdt.totalSupply(), supplyBefore + amount);
    }

    function testFuzz_ApproveAndTransferFrom(uint256 approveAmount, uint256 transferAmount) public {
        vm.assume(approveAmount > 0 && approveAmount <= INITIAL_SUPPLY);
        vm.assume(transferAmount > 0 && transferAmount <= approveAmount);

        usdt.approve(user1, approveAmount);
        
        vm.prank(user1);
        usdt.transferFrom(owner, user2, transferAmount);

        assertEq(usdt.balanceOf(user2), transferAmount);
        assertEq(usdt.allowance(owner, user1), approveAmount - transferAmount);
    }

    // ============================================
    // Integration Tests
    // ============================================

    function test_ComplexScenario() public {
        // 1. Owner distributes to users
        usdt.transfer(user1, 10_000 * 1e6);
        usdt.transfer(user2, 20_000 * 1e6);
        usdt.transfer(user3, 30_000 * 1e6);

        // 2. User1 approves user2 to spend
        vm.prank(user1);
        usdt.approve(user2, 5_000 * 1e6);

        // 3. User2 transfers from user1 to user3
        vm.prank(user2);
        usdt.transferFrom(user1, user3, 5_000 * 1e6);

        // 4. Owner issues more tokens
        usdt.issue(1_000_000 * 1e6);

        // 5. Owner blacklists user2
        usdt.addBlackList(user2);

        // 6. Verify final state
        assertEq(usdt.balanceOf(user1), 5_000 * 1e6);
        assertEq(usdt.balanceOf(user2), 20_000 * 1e6);
        assertEq(usdt.balanceOf(user3), 35_000 * 1e6);
        assertTrue(usdt.isBlackListed(user2));
        assertEq(usdt.totalSupply(), INITIAL_SUPPLY + 1_000_000 * 1e6);
    }

    function test_PauseResumeWorkflow() public {
        // Transfer works before pause
        usdt.transfer(user1, TRANSFER_AMOUNT);
        assertEq(usdt.balanceOf(user1), TRANSFER_AMOUNT);

        // Pause
        usdt.pause();

        // Transfer fails when paused
        vm.expectRevert();
        usdt.transfer(user1, TRANSFER_AMOUNT);

        // Unpause
        usdt.unpause();

        // Transfer works again
        usdt.transfer(user1, TRANSFER_AMOUNT);
        assertEq(usdt.balanceOf(user1), TRANSFER_AMOUNT * 2);
    }
}
