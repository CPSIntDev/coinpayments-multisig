// SPDX-License-Identifier: MIT
pragma solidity ^0.8.13;

import {Script, console} from "forge-std/Script.sol";
import {USDTMultisig} from "../src/Multisig.sol";

contract USDTMultisigScript is Script {
    USDTMultisig public multisig;

    function setUp() public {}

    function run() public {
        // Configuration - modify these for your deployment
        address usdtAddress = vm.envAddress("USDT_ADDRESS");
        uint256 threshold = vm.envUint("THRESHOLD");

        // Parse owners from environment (comma-separated)
        string memory ownersStr = vm.envString("OWNERS");
        address[] memory owners = parseOwners(ownersStr);

        console.log("Deploying USDTMultisig with OpenZeppelin...");
        console.log("USDT Address:", usdtAddress);
        console.log("Threshold:", threshold);
        console.log("Number of owners:", owners.length);

        vm.startBroadcast();

        multisig = new USDTMultisig(usdtAddress, owners, threshold);

        console.log("USDTMultisig deployed at:", address(multisig));

        vm.stopBroadcast();
    }

    function parseOwners(
        string memory ownersStr
    ) internal pure returns (address[] memory) {
        // Simple parsing - expects comma-separated addresses
        bytes memory strBytes = bytes(ownersStr);

        // Count commas to determine array size
        uint256 count = 1;
        for (uint256 i = 0; i < strBytes.length; i++) {
            if (strBytes[i] == ",") {
                count++;
            }
        }

        address[] memory owners = new address[](count);

        // Parse addresses
        uint256 start = 0;
        uint256 idx = 0;
        for (uint256 i = 0; i <= strBytes.length; i++) {
            if (i == strBytes.length || strBytes[i] == ",") {
                bytes memory addrBytes = new bytes(i - start);
                for (uint256 j = start; j < i; j++) {
                    addrBytes[j - start] = strBytes[j];
                }
                owners[idx] = parseAddress(string(addrBytes));
                start = i + 1;
                idx++;
            }
        }

        return owners;
    }

    function parseAddress(
        string memory addrStr
    ) internal pure returns (address) {
        bytes memory strBytes = bytes(addrStr);
        uint256 result = 0;

        // Skip "0x" prefix if present
        uint256 start = 0;
        if (
            strBytes.length >= 2 &&
            strBytes[0] == "0" &&
            (strBytes[1] == "x" || strBytes[1] == "X")
        ) {
            start = 2;
        }

        for (uint256 i = start; i < strBytes.length; i++) {
            uint8 b = uint8(strBytes[i]);
            uint8 val;

            if (b >= 48 && b <= 57) {
                val = b - 48; // 0-9
            } else if (b >= 65 && b <= 70) {
                val = b - 55; // A-F
            } else if (b >= 97 && b <= 102) {
                val = b - 87; // a-f
            } else {
                continue; // Skip invalid characters
            }

            result = result * 16 + val;
        }

        return address(uint160(result));
    }
}

// Simple deployment script without environment variables
contract SimpleDeployScript is Script {
    function run() public {
        // Hardcoded for testing - modify for your use case
        address usdt = 0xdAC17F958D2ee523a2206206994597C13D831ec7; // Mainnet USDT

        address[] memory owners = new address[](3);
        owners[0] = 0x1111111111111111111111111111111111111111;
        owners[1] = 0x2222222222222222222222222222222222222222;
        owners[2] = 0x3333333333333333333333333333333333333333;

        uint256 threshold = 2;

        vm.startBroadcast();

        USDTMultisig multisig = new USDTMultisig(usdt, owners, threshold);

        console.log("USDTMultisig deployed at:", address(multisig));

        vm.stopBroadcast();
    }
}
