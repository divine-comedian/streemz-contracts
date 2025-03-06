// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import "forge-std/Test.sol";
import "forge-std/console.sol";
import {StreemzCouncil} from "../contracts/StreemzCouncil.sol";
import {StreemzSuperApp} from "../contracts/StreemzSuperApp.sol";
import {Registry} from "../contracts/core/Registry.sol";
import {SuperfluidFrameworkDeployer} from "@superfluid-finance/ethereum-contracts/contracts/utils/SuperfluidFrameworkDeployer.sol";
import {SuperTokenDeployer} from "@superfluid-finance/ethereum-contracts/contracts/utils/SuperTokenDeployer.sol";
import {SuperToken} from "@superfluid-finance/ethereum-contracts/contracts/supertoken/SuperToken.sol";
import {ISuperfluid} from "@superfluid-finance/ethereum-contracts/contracts/interfaces/superfluid/ISuperfluid.sol";

contract StreemzIntegrationTest is Test {
    // Main contracts
    StreemzCouncil public council;
    StreemzSuperApp public superApp;
    Registry public registry;

    // Superfluid framework
    SuperfluidFrameworkDeployer.Framework internal sf;
    SuperfluidFrameworkDeployer internal sfDeployer;
    SuperToken public superToken;

    // Test accounts
    address public admin = address(1);
    address public member1 = address(2);
    address public member2 = address(3);
    address public grantee = address(4);

    // Constants
    int96 public constant EXPECTED_FLOW_RATE = 1000000000;
    uint256 public constant BASE_VOTING_POWER = 100;
    bytes32 public constant MEMBER_MANAGER_ROLE = keccak256("MEMBER_MANAGER_ROLE");
    bytes32 public constant GRANTEE_MANAGER_ROLE = keccak256("GRANTEE_MANAGER_ROLE");
    address public constant REGISTRY_ADDRESS = 0x4AAcca72145e1dF2aeC137E1f3C5E3D75DB8b5f3;
    uint256 public constant OPTIMISM_SEPOLIA_FORK_BLOCK = 5246167; // Replace with a recent block number

    function setUp() public {
        // Fork Optimism Sepolia
        vm.createSelectFork(
            vm.envString("OPTIMISM_SEPOLIA_RPC_URL"),
            OPTIMISM_SEPOLIA_FORK_BLOCK
        );

        // Setup accounts
        vm.startPrank(admin);
        
        // Connect to existing Registry
        registry = Registry(REGISTRY_ADDRESS);

        // Deploy Superfluid framework
        sfDeployer = new SuperfluidFrameworkDeployer();
        sf = sfDeployer.getFramework();

        // Deploy test SuperToken
        SuperTokenDeployer tokenDeployer = new SuperTokenDeployer();
        superToken = tokenDeployer.deployTestToken(sf.host, "Super Test Token", "STT", 18);

        // Deploy StreemzCouncil
        council = new StreemzCouncil(
            "Streemz Council",
            "SCOUNCIL",
            address(superToken),
            address(sf.gdaV1),
            REGISTRY_ADDRESS
        );

        // Deploy StreemzSuperApp
        superApp = new StreemzSuperApp(
            address(sf.host),
            EXPECTED_FLOW_RATE,
            address(council),
            BASE_VOTING_POWER
        );

        // Setup roles
        council.grantRole(MEMBER_MANAGER_ROLE, address(superApp));
        council.grantRole(GRANTEE_MANAGER_ROLE, admin);

        vm.stopPrank();
    }

    function test_InitialSetup() public {
        assertEq(council.registryAddress(), REGISTRY_ADDRESS);
        assertEq(superApp.council(), address(council));
        assertEq(superApp.expectedFlowRate(), EXPECTED_FLOW_RATE);
    }

    function test_CreateProfile() public {
        vm.startPrank(admin);
        
        // Create a profile for a grantee
        string memory name = "Test Grantee";
        Registry.Metadata memory metadata = Registry.Metadata({
            protocol: 1,
            pointer: "ipfs://test"
        });
        address[] memory members = new address[](1);
        members[0] = grantee;

        // Create profile using existing Registry
        bytes32 profileId = registry.createProfile(
            block.timestamp, // Using timestamp as nonce for uniqueness
            name,
            metadata,
            grantee,
            members
        );

        // Add profile as grantee to council
        council.addGrantee(profileId);

        // Verify grantee was added
        assertTrue(council.isGrantee(registry.getProfileById(profileId).anchor));
        vm.stopPrank();
    }

    function test_SuperAppFlow() public {
        vm.startPrank(member1);

        // Setup flow
        bytes memory userData = "";
        sf.host.callAgreement(
            sf.gdaV1,
            abi.encodeWithSelector(
                sf.gdaV1.createFlow.selector,
                superToken,
                address(superApp),
                EXPECTED_FLOW_RATE,
                userData
            ),
            userData
        );

        // Verify member was added to council
        assertTrue(council.balanceOf(member1) > 0);

        // Update flow to incorrect rate
        sf.host.callAgreement(
            sf.gdaV1,
            abi.encodeWithSelector(
                sf.gdaV1.updateFlow.selector,
                superToken,
                address(superApp),
                EXPECTED_FLOW_RATE + 1,
                userData
            ),
            userData
        );

        // Verify member was removed from council
        assertEq(council.balanceOf(member1), 0);

        vm.stopPrank();
    }

    function test_AdminFunctions() public {
        vm.startPrank(admin);

        // Test updating expected flow rate
        int96 newFlowRate = 2000000000;
        superApp.setExpectedFlowRate(newFlowRate);
        assertEq(superApp.expectedFlowRate(), newFlowRate);

        // Test updating council address
        address newCouncil = address(5);
        superApp.setCouncil(newCouncil);
        assertEq(superApp.council(), newCouncil);

        vm.stopPrank();
    }

    function test_GranteeManagement() public {
        vm.startPrank(admin);

        // Create profile using existing Registry
        bytes32 profileId = registry.createProfile(
            block.timestamp, // Using timestamp as nonce for uniqueness
            "Test Grantee",
            Registry.Metadata({protocol: 1, pointer: "ipfs://test"}),
            grantee,
            new address[](0)
        );

        // Add grantee
        council.addGrantee(profileId);
        assertTrue(council.isGrantee(registry.getProfileById(profileId).anchor));

        // Remove grantee
        council.removeGrantee(profileId);
        assertFalse(council.isGrantee(registry.getProfileById(profileId).anchor));

        vm.stopPrank();
    }

    // Helper function to deal with revert messages
    function expectRevert(bytes memory expectedError) internal {
        vm.expectRevert(expectedError);
    }
} 