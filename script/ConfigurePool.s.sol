// SPDX-License-Identifier: MIT

pragma solidity ^0.8.24;

import {Script} from "forge-std/Script.sol";
import {TokenPool} from "@ccip/contracts/src/v0.8/ccip/pools/TokenPool.sol";

import {RateLimiter} from "@ccip/contracts/src/v0.8/ccip/libraries/RateLimiter.sol";

contract ConfigurePoolScript is Script {
    function run(
        address localPool,
        uint64 remoteChainSelector, // The unique identifier of the target blockchain.
        address remotePool, //
        address remoteToken, //
        bool outboundRateLimiterIsEnabled, //
        uint128 outboundRateLimiterCapacity, //
        uint128 outboundRateLimiterRate, //
        bool inboundRateLimiterIsEnabled, //
        uint128 inboundRateLimiterCapacity, //
        uint128 inboundRateLimiterRate //
    ) public {
        vm.startBroadcast();
        bytes[] memory remotePoolAddresses = new bytes[](1);
        remotePoolAddresses[0] = abi.encode(remotePool);
        TokenPool.ChainUpdate[] memory chainsToAdd = new TokenPool.ChainUpdate[](1);
        chainsToAdd[0] = TokenPool.ChainUpdate({
            remoteChainSelector: remoteChainSelector, // The unique identifier of the target blockchain.
            remotePoolAddresses: remotePoolAddresses, //An array of ABI-encoded addresses of the pool(s) on the remote chain.
            remoteTokenAddress: abi.encode(remoteToken), // The ABI-encoded address of the token contract on the remote chain.
            outboundRateLimiterConfig: // Configuration for rate-limiting tokens leaving the current pool.
            RateLimiter.Config({
                isEnabled: outboundRateLimiterIsEnabled,
                capacity: outboundRateLimiterCapacity,
                rate: outboundRateLimiterRate
            }),
            inboundRateLimiterConfig: // Configuration for rate-limiting tokens arriving at the current pool.
            RateLimiter.Config({
                isEnabled: inboundRateLimiterIsEnabled,
                capacity: inboundRateLimiterCapacity,
                rate: inboundRateLimiterRate
            })
        });
        TokenPool(localPool).applyChainUpdates(new uint64[](0), chainsToAdd);
        vm.stopBroadcast();
    }
}
