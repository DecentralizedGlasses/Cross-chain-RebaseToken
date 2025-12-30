// SPDX-License-Identifier: MIT

pragma solidity ^0.8.30;

import {Test, console} from "forge-std/Test.sol";
import {RebaseToken} from "../src/RebaseToken.sol";
import {Vault} from "../src/Vault.sol";
import {IRebaseToken} from "../src/Interfaces/IrebaseToken.sol";
import {Ownable} from "@openzeppelin/contracts/access/Ownable.sol";
import {IAccessControl} from "@openzeppelin/contracts/access/AccessControl.sol";

contract RebaseTokenTest is Test {
    // creating instances of that contracts to use them in this test contract
    RebaseToken private rebaseToken;
    Vault private vault;

    uint256 public SEND_VALUE = 1e5;

    // creating deterministic addresses for the user and owner
    address public owner = makeAddr("owner");
    address public user = makeAddr("user");

    function setUp() public {
        vm.startPrank(owner);
        rebaseToken = new RebaseToken();

        // Deploy Vault: requires IRebaseToken.
        // Direct casting (IRebaseToken(rebaseToken)) is invalid.
        // Correct way: cast rebaseToken to address, then to IRebaseToken.
        vault = new Vault(IRebaseToken(address(rebaseToken))); // Deploying the Vault, ensuring correct type casting for its constructor argument.

        rebaseToken.grantMintAndBurnRole(address(vault)); // granting the vault contract the neccessary permissions to mint and burn RebaseToken s

        // Send 1 ETH to the Vault to simulate initial funds.
        // The target address must be cast to 'payable'.
        (bool success,) = payable(address(vault)).call{value: 1e18}(""); // low-level calling with .call, .send, .transfer will return a boolean value
        vm.stopPrank();
    }

    function addRewardsToVault(uint256 rewardAmount) public {
        (bool success,) = payable(address(vault)).call{value: rewardAmount}("");
    }

    function testDepositLinear(uint256 amount) public {
        // vm.assume(amount > 1e4);

        // Constrain the fuzzed 'amount' to a practical range.
        // Min: 0.00001 ETH (1e5 wei), Max: type(uint96).max to avoid overflows.
        amount = bound(amount, 1e5, type(uint96).max);

        // 1. deposit : user deposits amount ETH
        vm.startPrank(user);
        vm.deal(user, amount); // Give 'user' the 'amount' of ETH to deposit

        vault.deposit{value: amount}(); //depositing into the vault
        // 2. check our rebase token
        uint256 startBalance = rebaseToken.balanceOf(user);
        console.log("startingBalance", startBalance);
        assertEq(startBalance, amount); //checking both start balance and amount are same since no time passed
        // 3. warp the time and check the balance again
        vm.warp(block.timestamp + 1 hours); // increase the time by one hour
        uint256 middleBalance = rebaseToken.balanceOf(user);
        assertGt(middleBalance, startBalance); // middleBalance > startBalance
        // 4. warp the time again by the same amount and check the balance again
        vm.warp(block.timestamp + 1 hours);
        uint256 endBalance = rebaseToken.balanceOf(user);
        assertGt(endBalance, middleBalance);

        assertApproxEqAbs(endBalance - middleBalance, middleBalance - startBalance, 1); // we're using assert approximate equal absolute
        vm.stopPrank();
    }

    function testRedeemStraightAway(uint256 amount) public {
        amount = bound(amount, 1e5, type(uint96).max);
        // 1. deposit the funds
        vm.startPrank(user);
        vm.deal(user, amount);
        // we need to deposit it into the vault
        vault.deposit{value: amount}();
        assertEq(rebaseToken.balanceOf(user), amount); //checking the initial balance of the user is as same as amount

        // 2. redeem
        vault.redeem(type(uint256).max); //redeeming entire balance
        assertEq(rebaseToken.balanceOf(user), 0); //checking the balance of user
        assertEq(address(user).balance, amount); // checking the eth balance of user is equal to amount
        vm.stopPrank;
    }

    function testRedeemAfterTimePassed(uint256 depositAmount, uint256 time) public {
        time = bound(time, 1000, type(uint96).max);
        depositAmount = bound(depositAmount, 1e5, type(uint96).max);

        // 1. deposit the amount
        vm.prank(user);
        vm.deal(user, depositAmount);
        vault.deposit{value: depositAmount}();

        // 2. warp the time
        vm.warp(block.timestamp + time);
        uint256 balanceAfterSomeTime = rebaseToken.balanceOf(user);

        // 2.b: Add rewards to the vault
        vm.deal(owner, balanceAfterSomeTime - depositAmount);
        vm.prank(owner);
        addRewardsToVault(balanceAfterSomeTime - depositAmount);

        // 3.redeem balance
        vm.prank(user);
        vault.redeem(type(uint256).max); // redeeming all amount

        // assertEq(address(user).balance, 0);
        //vm.stopPrank();

        uint256 ethBalance = address(user).balance;
        assertEq(ethBalance, balanceAfterSomeTime);
        assertGt(ethBalance, depositAmount);
    }

    function testTransfer(uint256 amount, uint256 amountToSend) public {
        amount = bound(amount, 1e5 + 1e5, type(uint96).max);
        amountToSend = bound(amountToSend, 1e5, amount - 1e5);

        // 1.deposit
        vm.deal(user, amount);
        vm.prank(user);
        vault.deposit{value: amount}();

        // creating another user before making transaction
        address user2 = makeAddr("user2");
        uint256 userBalance = rebaseToken.balanceOf(user);
        uint256 user2Balance = rebaseToken.balanceOf(user2);
        assertEq(userBalance, amount);
        assertEq(user2Balance, 0);

        // owner reduces interest rate
        vm.prank(owner);
        rebaseToken.setInterestRate(4e10); // before it is 5e10 now reduced to 4e10

        // 2. transfer
        vm.prank(user);
        rebaseToken.transfer(user2, amountToSend);
        uint256 userBalanceAfterTransfer = rebaseToken.balanceOf(user);
        uint256 user2BalanceAfterTransfer = rebaseToken.balanceOf(user2);
        assertEq(userBalanceAfterTransfer, userBalance - amountToSend);
        assertEq(user2BalanceAfterTransfer, amountToSend);

        // check the interest rate is inherited (5e10 to 4e10)
        assertEq(rebaseToken.getUserInterestRate(user), 5e10);
        assertEq(rebaseToken.getUserInterestRate(user2), 5e10);
    }

    function testCannotSetInterestRate(uint256 newInterestRate) public {
        vm.prank(user);
        vm.expectPartialRevert(Ownable.OwnableUnauthorizedAccount.selector);
        rebaseToken.setInterestRate(newInterestRate);
    }

    // function testCannotCallMintAndBurn() public {
    //     vm.prank(user);
    //     vm.expectPartialRevert(bytes4(IAccessControl.AccessControlUnauthorizedAccount.selector));
    //     rebaseToken.mint(user, 100, rebaseToken.getInterestRate());
    //     vm.prank(user);
    //     vm.expectPartialRevert(bytes4(IAccessControl.AccessControlUnauthorizedAccount.selector));
    //     rebaseToken.burn(user, 100);
    // }

    function testCannotCallMint() public {
        // Deposit funds
        vm.startPrank(user);
        uint256 interestRate = rebaseToken.getInterestRate();
        vm.expectRevert();
        rebaseToken.mint(user, SEND_VALUE, interestRate);
        vm.stopPrank();
    }

    function testCannotCallBurn() public {
        // Deposit funds
        vm.startPrank(user);
        vm.expectRevert();
        rebaseToken.burn(user, SEND_VALUE);
        vm.stopPrank();
    }

    function testGetPrincpleAmount(uint256 amount) public {
        amount = bound(amount, 1e5, type(uint96).max);

        // 1. deposit
        vm.deal(user, amount);
        vm.prank(user);
        vault.deposit{value: amount}();
        assertEq(rebaseToken.principleBalanceOf(user), amount);

        vm.warp(block.timestamp + 1 hours);
        assertEq(rebaseToken.principleBalanceOf(user), amount);
    }

    function testGetRebaseTokenAddress() public view {
        assertEq(vault.getRebaseTokenAddress(), address(rebaseToken));
    }

    function testInterestCanOnlyDecrease(uint256 newInterestRate) public {
        uint256 initialInterestRate = rebaseToken.getInterestRate();
        newInterestRate = bound(newInterestRate, rebaseToken.getInterestRate(), type(uint96).max);
        vm.prank(owner);
        vm.expectPartialRevert(RebaseToken.RebaseToken__InterestRateCanOnlyDecrease.selector);
        rebaseToken.setInterestRate(newInterestRate);
        assertEq(rebaseToken.getInterestRate(), initialInterestRate);
    }
}
