// SPDX-License-Identifier: MIT

pragma solidity ^0.8.24;

import {TokenPool} from "@ccip/contracts/src/v0.8/ccip/pools/TokenPool.sol";
import {Pool} from "@ccip/contracts/src/v0.8/ccip/libraries/Pool.sol"; // imported to use CCIP defined structs, such as Pool.LockOrBurnInV1

import {Client} from "@ccip/contracts/src/v0.8/ccip/libraries/Client.sol";

import {IERC20} from "lib/ccip/contracts/src/v0.8/vendor/openzeppelin-solidity/v4.8.3/contracts/token/ERC20/IERC20.sol";
import {IRebaseToken} from "./Interfaces/IrebaseToken.sol";

contract RebaseTokenPool is TokenPool {
    error OnlyRouterAllowed();
    //_token: The address of the rebase token this pool will manage.
    // localTokenDecimals: The decimals of the token. Here, it's hardcoded to 18.
    // _allowlist: An array of addresses permitted to send tokens through this pool.
    // _rnmProxy: The address of the CCIP Risk Management Network (RMN) proxy.
    // _router: The address of the CCIP router contract.
    constructor(IERC20 _token, address[] memory _allowlist, address _rmnProxy, address _router)
        TokenPool(_token, 18, _allowlist, _rmnProxy, _router)
    {}

    function lockOrBurn(Pool.LockOrBurnInV1 calldata lockOrBurnIn)
        external
        virtual
        override
        returns (Pool.LockOrBurnOutV1 memory lockOrBurnOut)
    {
        // this is crucial because this performa crucial security and configuration checks
        _validateLockOrBurn(lockOrBurnIn);

        // Decode the original sender's address
        address sender = lockOrBurnIn.originalSender;
        // address sender = abi.decode(lockOrBurnIn.originalSender, (address)); // lockOrBurnIn.originalSender is provided as bytes, we abi.decode to get the address of the user initiating cross chain transfer
        // we then call getUserInterestRate(originalSender) on our rebaseToken contract (accessed via i_token, a state variable from TokenPool holding the token's address, cast to IRebaseToken) to retrieve the sender's current interest rate.

        // Fetch the user's current interest rate from the rebase token

        uint256 userInterestRate = IRebaseToken(address(i_token)).getUserInterestRate(sender);

        // Burn the specified amount of tokens from this pool contract
        // IRebaseToken(address(i_token)).burn(address(this), lockOrBurnIn.amount): The specified lockOrBurnIn.amount of tokens is burned. Importantly, the tokens are burned from the pool contract's balance (address(this)). This is because the CCIP router first transfers the user's tokens to this pool contract before lockOrBurn is executed.
        // CCIP transfers tokens to the pool before lockOrBurn is called
        IRebaseToken(address(i_token)).burn(address(this), lockOrBurnIn.amount);

        // Prepare the output data for CCIP
        lockOrBurnOut = Pool.LockOrBurnOutV1({
            // getRemoteToken() is a helper function from TokenPool that resolves this based on the lockOrBurnIn.remoteChainSelector.
            destTokenAddress: getRemoteToken(lockOrBurnIn.remoteChainSelector), // This is the address of the corresponding token contract on the destination chain.
            destPoolData: abi.encode(userInterestRate) // encode the user interest rate and include it in cross-chain transfer
        });
        // No explicit return statement is needed due to the named return variable
    }

    function releaseOrMint(Pool.ReleaseOrMintInV1 calldata releaseOrMintIn)
        external
        virtual
        override
        returns (Pool.ReleaseOrMintOutV1 memory)
    {
        // // performs necessary security and configuration checks for incoming messages
        _validateReleaseOrMint(releaseOrMintIn);

        // // releaseOrMintIn.receiver directly provides the address of the intended recipient of the tokens on this destination chain.
        // // The receiver address is directly available
        address receiver = releaseOrMintIn.receiver;

        // // userInterestRate is retrieved by abi.decodeing releaseOrMintIn.sourcePoolData.
        // // This sourcePoolData is the destPoolData that was encoded and sent by the lockOrBurn function on the source chain.
        // // Decode the user interest rate sent from the source pool
        (uint256 userInterestRate) = abi.decode(releaseOrMintIn.sourcePoolData, (uint256));

        // // New tokens are minted for the receiver.
        // // The releaseOrMintIn.amount dictates how many tokens are minted.
        // // Crucially, the userInterestRate received from the source chain is passed to the mint function of our IRebaseToken. This presumes your rebase token's mint function has been modified to accept this _userInterestRate parameter, allowing it to correctly initialize or update the user's rebase-specific state. This ensures the user's rebase benefits are maintained cross-chain.

        // // Mint tokens to the receiver, applying the propagated interest rate
        IRebaseToken(address(i_token)).mint(receiver, releaseOrMintIn.amount, userInterestRate); // Pass the interest rate to the rebase token's mint function

        // // The function returns a Pool.ReleaseOrMintOutV1 struct, primarily indicating the destinationAmount (the amount of tokens minted).
        return Pool.ReleaseOrMintOutV1({destinationAmount: releaseOrMintIn.amount});
        // revert("Not used in Programmable mode");
    }
}
