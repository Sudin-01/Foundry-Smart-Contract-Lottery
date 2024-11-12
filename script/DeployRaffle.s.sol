// SPDX-License-Identifier: MIT
pragma solidity ^0.8.19;

import {Script} from "forge-std/Script.sol";
import {Raffle} from "../src/Raffle.sol";
import {HelperConfig} from "../script/HelperConfig.s.sol";
import {CreateSubscription, FundSubscriptions, AddConsumer} from "../script/Interaction.s.sol";

contract DeployRaffle is Script {
    function run() external {}

    function deployContract() public returns (Raffle, HelperConfig) {
        HelperConfig helperConfig = new HelperConfig();
        HelperConfig.NetworkConfig memory config = helperConfig.getConfig();
        //local network->DEploy and get the config
        //sepolia network->Get the config
        if (config.subscriptionID == 0) {
            //Create a subscriptionID
            CreateSubscription createSubscription = new CreateSubscription();
            (config.subscriptionID, config.vrfCoordinator) = createSubscription
                .createSubcscriptions(config.vrfCoordinator, config.account);

            //FundSubscriptions
            FundSubscriptions fundsubscriptions = new FundSubscriptions();
            fundsubscriptions.FundSubscription(
                config.vrfCoordinator,
                config.subscriptionID,
                config.linktokens,
                config.account
            );
        }

        vm.startBroadcast(config.account);
        Raffle raffle = new Raffle(
            config.entrancefee,
            config.interval,
            config.vrfCoordinator,
            config.gasLane,
            config.callbackGasLimit,
            config.subscriptionID
        );

        vm.stopBroadcast();

        AddConsumer addconsumer = new AddConsumer();
        addconsumer.addConsumer(
            address(raffle),
            config.vrfCoordinator,
            config.subscriptionID,
            config.account
        );
        return (raffle, helperConfig);
    }
}
