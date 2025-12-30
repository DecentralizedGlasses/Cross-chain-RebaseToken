// SPDX-License-Identifier: MIT

// Layout of Contract:
// version
// imports
// interfaces, libraries, contracts
// errors
// Type declarations
// State variables
// Events
// Modifiers
// Functions

// Layout of Functions:
// constructor
// receive function (if exists)
// fallback function (if exists)
// external
// public
// internal
// private
// view & pure functions

pragma solidity ^0.8.24;

import {IRebaseToken} from "./Interfaces/IrebaseToken.sol";

contract Vault {
    // Core Requirements:
    // 1. Store the address of the RebaseToken contract (passed in constructor).
    // 2. Implement a deposit function:
    //    - Accepts ETH from the user.
    //    - Mints RebaseTokens to the user, equivalent to the ETH sent (1:1 peg initially).
    // 3. Implement a redeem function:
    //    - Burns the user's RebaseTokens.
    //    - Sends the corresponding amount of ETH back to the user.
    // 4. Implement a mechanism to add ETH rewards to the vault.

    // We need to pass the token address to constructor
    // Create a deposut function that mints tokens to the user equal to the amount of ETH that user has sent
    // Create a redeem function that burns tokens from the user and sends the user ETH
    // Create way too add rewards to the vault

    IRebaseToken public immutable i_rebaseToken;

    event Deposit(address indexed user, uint256 amount);
    event Redeem(address indexed user, uint256 amount);

    error Vault__RedeemFailed();
    error Vault__DepositAmountIsZero();

    constructor(IRebaseToken _rebaseToken) {
        i_rebaseToken = _rebaseToken;
    }
    // allows the contract to receive rewards
    receive() external payable {}

    /**
     * @notice Allows users to deposit ETH and mint Rebase tokens in return
     *
     */
    function deposit() external payable {
        // We need to use the amount of ETH the user has sent to mint the tokens to the user.
        // The amount of ETH sent is msg.value
        // The user making the call is msg.sender
        // uint256 amountToMint = msg.value;
        // if (amountToMint == 0) {
        //     revert Vault__DepositAmountIsZero();
        // }
        // uint256 interestRate = i_rebaseToken.getInterestRate();
        i_rebaseToken.mint(msg.sender, msg.value, i_rebaseToken.getInterestRate());
        // emit an event after depositing
        emit Deposit(msg.sender, msg.value);
    }

    /**
     * @notice Allows users to redeem their rebase tokens for ETH
     * @param _amount -> the amount of rebase tokens user want to redeem
     */

    function redeem(uint256 _amount) external {
        if (_amount == type(uint256).max) {
            _amount = i_rebaseToken.balanceOf(msg.sender);
        }
        // 1. burn the tokens from the user
        i_rebaseToken.burn(msg.sender, _amount);
        // 2. We need to send the user ETH
        (bool success,) = payable(msg.sender).call{value: _amount}("");
        if (!success) {
            revert Vault__RedeemFailed();
        }
        emit Redeem(msg.sender, _amount);
    }

    /**
     * @notice get the address of the rebase token
     * @return address of the rebase token
     */
    function getRebaseTokenAddress() external view returns (address) {
        return address(i_rebaseToken); // if we don't do casting it will take it as an interface
    }
}
