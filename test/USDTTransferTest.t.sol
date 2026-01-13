// SPDX-License-Identifier: MIT
pragma solidity ^0.8.13;

import "forge-std/Test.sol";
//import {IERC20} from "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import "../src/Multisig.sol";
import "../src/interfaces/ITetherToken.sol";

/**
 * @title USDTTransferTest
 * @notice Test suite specifically for debugging USDT transfers with legacy TetherToken
 */
contract USDTTransferTest is Test {
    ITetherToken public usdt;
    USDTMultisig public multisig;

    address public owner1 = address(0x1);
    address public owner2 = address(0x2);
    address public owner3 = address(0x3);
    address public recipient = address(0x999);

    uint256 constant INITIAL_SUPPLY = 1_000_000_000 * 1e6; // 1B USDT
    uint256 constant MULTISIG_BALANCE = 1_000_000 * 1e6; // 1M USDT

    function setUp() public {
        // Deploy TetherToken using bytecode
        bytes memory tetherBytecode = vm.getCode(
            "out-trc20/TetherToken.sol/TetherToken.json"
        );
        bytes memory constructorArgs = abi.encode(
            INITIAL_SUPPLY,
            "Tether USD",
            "USDT",
            uint8(6)
        );

        address tetherAddr;
        bytes memory bytecodeWithArgs = abi.encodePacked(
            tetherBytecode,
            constructorArgs
        );
        assembly {
            tetherAddr := create(
                0,
                add(bytecodeWithArgs, 0x20),
                mload(bytecodeWithArgs)
            )
        }
        require(tetherAddr != address(0), "TetherToken deployment failed");
        usdt = ITetherToken(tetherAddr);

        // Setup owners
        address[] memory owners = new address[](3);
        owners[0] = owner1;
        owners[1] = owner2;
        owners[2] = owner3;

        // Deploy Multisig with threshold 2
        multisig = new USDTMultisig(address(usdt), owners, 2);

        // Transfer USDT to multisig
        usdt.transfer(address(multisig), MULTISIG_BALANCE);

        // Give owners some ETH for gas
        vm.deal(owner1, 10 ether);
        vm.deal(owner2, 10 ether);
        vm.deal(owner3, 10 ether);
    }

    function test_TetherToken_DirectTransfer() public {
        // Test that TetherToken can transfer directly
        uint256 balanceBefore = usdt.balanceOf(recipient);

        // Transfer from this contract (owner of USDT)
        usdt.transfer(recipient, 1000 * 1e6);

        uint256 balanceAfter = usdt.balanceOf(recipient);
        assertEq(balanceAfter - balanceBefore, 1000 * 1e6);
    }

    function test_TetherToken_TransferReturnValue() public {
        // Check what TetherToken returns from transfer
        (bool success, bytes memory data) = address(usdt).call(
            abi.encodeWithSelector(
                IERC20.transfer.selector,
                recipient,
                1000 * 1e6
            )
        );

        console.log("Direct transfer success:", success);
        console.log("Return data length:", data.length);
        if (data.length > 0) {
            console.log("Return data (bool):", abi.decode(data, (bool)));
        }

        assertTrue(success, "Transfer call should succeed");
    }

    function test_Multisig_CanHoldUSDT() public {
        assertEq(usdt.balanceOf(address(multisig)), MULTISIG_BALANCE);
    }

    function test_Multisig_SubmitAndApprove_ShouldTransfer() public {
        uint256 amount = 100 * 1e6; // 100 USDT

        // Owner1 submits (auto-approves, so approvalCount = 1)
        vm.prank(owner1);
        multisig.submitTransaction(recipient, amount);

        // Check transaction was created
        (
            address to,
            uint256 txAmount,
            bool executed,
            uint256 approvalCount,
            ,

        ) = multisig.getTransaction(0);
        assertEq(to, recipient);
        assertEq(txAmount, amount);
        assertFalse(executed);
        assertEq(approvalCount, 1);

        // Owner2 approves - this should trigger execution (threshold = 2)
        uint256 recipientBalanceBefore = usdt.balanceOf(recipient);
        uint256 multisigBalanceBefore = usdt.balanceOf(address(multisig));

        console.log("Recipient balance before:", recipientBalanceBefore);
        console.log("Multisig balance before:", multisigBalanceBefore);

        vm.prank(owner2);
        multisig.approveTransaction(0);

        // Check transaction was executed
        (, , bool executedAfter, , , ) = multisig.getTransaction(0);
        assertTrue(executedAfter, "Transaction should be executed");

        uint256 recipientBalanceAfter = usdt.balanceOf(recipient);
        uint256 multisigBalanceAfter = usdt.balanceOf(address(multisig));

        console.log("Recipient balance after:", recipientBalanceAfter);
        console.log("Multisig balance after:", multisigBalanceAfter);

        assertEq(recipientBalanceAfter, recipientBalanceBefore + amount);
        assertEq(multisigBalanceAfter, multisigBalanceBefore - amount);
    }

    function test_LowLevelCall_FromMultisigContext() public {
        // Simulate what happens in _executeTransaction
        uint256 amount = 100 * 1e6;
        uint256 recipientBefore = usdt.balanceOf(recipient);

        // Multisig holds USDT, let's try a low-level call from multisig's perspective
        vm.prank(address(multisig));
        (bool success, bytes memory data) = address(usdt).call(
            abi.encodeWithSelector(IERC20.transfer.selector, recipient, amount)
        );

        console.log("Low-level call success:", success);
        console.log("Return data length:", data.length);

        if (data.length > 0) {
            bool returnValue = abi.decode(data, (bool));
            console.log("Return value:", returnValue);
            // TetherToken returns FALSE even on success!
            assertFalse(
                returnValue,
                "TetherToken returns false even on success"
            );
        }

        // The CORRECT way to check: verify balance changed
        uint256 recipientAfter = usdt.balanceOf(recipient);
        assertEq(
            recipientAfter,
            recipientBefore + amount,
            "Balance should increase"
        );
        assertTrue(success, "Call should succeed");
    }

    function test_Debug_TransferFromMultisig() public {
        uint256 amount = 100 * 1e6;

        console.log("=== Debug Transfer ===");
        console.log("Multisig address:", address(multisig));
        console.log("USDT address:", address(usdt));
        console.log("Recipient:", recipient);
        console.log("Amount:", amount);
        console.log(
            "Multisig USDT balance:",
            usdt.balanceOf(address(multisig))
        );

        // Check if multisig is blacklisted
        console.log(
            "Is multisig blacklisted:",
            usdt.isBlackListed(address(multisig))
        );
        console.log("Is recipient blacklisted:", usdt.isBlackListed(recipient));

        // Check if paused
        console.log("Is USDT paused:", usdt.paused());

        // Try transfer
        vm.prank(address(multisig));
        (bool success, bytes memory data) = address(usdt).call(
            abi.encodeWithSelector(IERC20.transfer.selector, recipient, amount)
        );

        console.log("Call success:", success);
        console.log("Data length:", data.length);

        if (!success) {
            console.log("TRANSFER FAILED!");
            if (data.length > 0) {
                console.logBytes(data);
            }
        }
    }

    function test_StandardToken_TransferBehavior() public {
        // Test the actual transfer function behavior
        uint256 amount = 100 * 1e6;
        uint256 balanceBefore = usdt.balanceOf(address(multisig));
        uint256 recipientBefore = usdt.balanceOf(recipient);

        console.log("Testing StandardToken.transfer behavior");
        console.log("Sender (multisig):", address(multisig));
        console.log("Sender balance:", balanceBefore);

        // NOTE: TetherToken (Solidity 0.4.x) has a bug where transfer returns false
        // even when the transfer succeeds. This is why we verify via balance change.

        vm.prank(address(multisig));
        bool result = usdt.transfer(recipient, amount);

        console.log("Transfer returned:", result);

        // TetherToken returns false even on success - this is a known bug
        assertFalse(result, "TetherToken returns false (known bug)");

        // But the transfer actually succeeded - verify via balance
        assertEq(
            usdt.balanceOf(recipient),
            recipientBefore + amount,
            "Transfer actually worked"
        );
        assertEq(
            usdt.balanceOf(address(multisig)),
            balanceBefore - amount,
            "Sender balance decreased"
        );
    }
}
