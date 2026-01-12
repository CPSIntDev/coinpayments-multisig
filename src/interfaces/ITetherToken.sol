// SPDX-License-Identifier: MIT
pragma solidity ^0.8.13;

/**
 * @title ITetherToken
 * @notice Interface for the TetherToken (TRC20 USDT) contract
 * @dev This interface allows interaction with the legacy Solidity 0.4.x TetherToken
 */
interface ITetherToken {
    // ERC20 standard functions
    function name() external view returns (string memory);
    function symbol() external view returns (string memory);
    function decimals() external view returns (uint8);
    function totalSupply() external view returns (uint256);
    function balanceOf(address who) external view returns (uint256);
    function transfer(address to, uint256 value) external returns (bool);
    function transferFrom(address from, address to, uint256 value) external returns (bool);
    function approve(address spender, uint256 value) external returns (bool);
    function allowance(address owner, address spender) external view returns (uint256);

    // TetherToken specific functions
    function issue(uint256 amount) external;
    function redeem(uint256 amount) external;
    function owner() external view returns (address);
    
    // Pausable
    function pause() external;
    function unpause() external;
    function paused() external view returns (bool);
    
    // BlackList
    function addBlackList(address _evilUser) external;
    function removeBlackList(address _clearedUser) external;
    function isBlackListed(address _user) external view returns (bool);
    function destroyBlackFunds(address _blackListedUser) external;

    // Events
    event Transfer(address indexed from, address indexed to, uint256 value);
    event Approval(address indexed owner, address indexed spender, uint256 value);
    event Issue(uint256 amount);
    event Redeem(uint256 amount);
    event Deprecate(address newAddress);
    event DestroyedBlackFunds(address indexed _blackListedUser, uint256 _balance);
    event AddedBlackList(address indexed _user);
    event RemovedBlackList(address indexed _user);
    event Pause();
    event Unpause();
}
