// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import {Council} from "./Council.sol";
import {Registry} from "./core/Registry.sol";

contract StreemzCouncil is Council {
    Registry private registry;
    address public registryAddress;

    constructor(
        string memory _name,
        string memory _symbol,
        address _distributionToken,
        address _gdav1Forwarder,
        address _registry
    ) NonTransferableToken(_name, _symbol) PoolManager(_distributionToken, _gdav1Forwarder) {
        registry = Registry(_registry);
        registryAddress = _registry;
        gdav1Forwarder = _gdav1Forwarder;
        maxAllocationsPerMember = MAX_ALLOCATIONS_PER_MEMBER;
        _grantRole(DEFAULT_ADMIN_ROLE, msg.sender);
        _grantRole(MEMBER_MANAGER_ROLE, msg.sender);
        _grantRole(GRANTEE_MANAGER_ROLE, msg.sender);
    }

    function addGrantee(bytes32 profileId) public onlyRole(GRANTEE_MANAGER_ROLE) {
        Profile grantee = registry.getProfileById(profileId);
        if (isGrantee(grantee.anchor)) revert GranteeAlreadyAdded();
        _addGrantee(grantee.anchor);
        emit GranteeAdded(grantee.name, grantee.anchor);
    }

    /**
     * @notice Remove a grantee
     * @param _grantee Address of the grantee to remove
     */
    function removeGrantee(bytes32 profileId) public onlyRole(GRANTEE_MANAGER_ROLE) {
        Profile grantee = registry.getProfileById(profileId);
        _removeGrantee(grantee.anchor);
        emit GranteeRemoved(grantee.anchor);
    }
}
