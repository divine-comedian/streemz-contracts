// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import "forge-std/Script.sol";
import {StreemzCouncil} from "../contracts/StreemzCouncil.sol";
import {StreemzSuperApp} from "../contracts/StreemzSuperApp.sol";
import {Registry} from "../contracts/core/Registry.sol";
import {ISuperfluid} from "@superfluid-finance/ethereum-contracts/contracts/interfaces/superfluid/ISuperfluid.sol";

contract DeployStreemz is Script {
    // Configuration
    string constant COUNCIL_NAME = "Streemz Council";
    string constant COUNCIL_SYMBOL = "SCOUNCIL";
    int96 constant EXPECTED_FLOW_RATE = 1000000000;
    uint256 constant BASE_VOTING_POWER = 100;

    // Contract instances
    StreemzCouncil public council;
    StreemzSuperApp public superApp;
    Registry public registry;

    // Roles
    bytes32 public constant MEMBER_MANAGER_ROLE = keccak256("MEMBER_MANAGER_ROLE");
    bytes32 public constant GRANTEE_MANAGER_ROLE = keccak256("GRANTEE_MANAGER_ROLE");

    function run() external {
        // Get deployment configuration from environment
        uint256 deployerPrivateKey = vm.envUint("PRIVATE_KEY");
        address superfluidHost = vm.envAddress("SUPERFLUID_HOST");
        address gdaV1 = vm.envAddress("SUPERFLUID_GDA");
        address distributionToken = vm.envAddress("DISTRIBUTION_TOKEN");

        vm.startBroadcast(deployerPrivateKey);

        // Deploy Registry
        registry = new Registry();
        registry.initialize(msg.sender);
        console.log("Registry deployed at:", address(registry));

        // Deploy StreemzCouncil
        council = new StreemzCouncil(
            COUNCIL_NAME,
            COUNCIL_SYMBOL,
            distributionToken,
            gdaV1,
            address(registry)
        );
        console.log("StreemzCouncil deployed at:", address(council));

        // Deploy StreemzSuperApp
        superApp = new StreemzSuperApp(
            superfluidHost,
            EXPECTED_FLOW_RATE,
            address(council),
            BASE_VOTING_POWER
        );
        console.log("StreemzSuperApp deployed at:", address(superApp));

        // Setup roles
        council.grantRole(MEMBER_MANAGER_ROLE, address(superApp));
        council.grantRole(GRANTEE_MANAGER_ROLE, msg.sender);

        vm.stopBroadcast();

        // Log deployment summary
        console.log("\nDeployment Summary:");
        console.log("------------------");
        console.log("Registry:", address(registry));
        console.log("StreemzCouncil:", address(council));
        console.log("StreemzSuperApp:", address(superApp));
        console.log("Deployer:", msg.sender);
    }
} 