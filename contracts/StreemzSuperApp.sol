import {SuperAppBase} from "@superfluid-finance/ethereum-contracts/contracts/apps/SuperAppBaseFlow.sol";
import {Ownable} from "@openzeppelin/contracts/access/Ownable.sol";

interface Council {
    function addCouncilMember(address _member, uint256 _votingPower) external;

    function removeCouncilMember(address _member) external;
}

contract StreemzSuperApp is SuperAppBase, Ownable {
    int96 public expectedFlowRate;
    address public council;
    uint256 private baseVotingPower;

    constructor(address _host, int96 _expectedFlowRate, address _council, uint256 _baseVotingPower)
        SuperAppBase(_host)
        Ownable(_host)
    {
        expectedFlowRate = _expectedFlowRate;
        council = _council;
        baseVotingPower = _baseVotingPower;
    }

    function onFlowCreated(int96 previousFlowRate, int96 newFlowRate, address sender, bytes calldata ctx)
        internal
        virtual
        override
        returns (bytes memory newCtx)
    {
        if (newFlowRate == expectedFlowRate) {
            Council(council).addCouncilMember(sender, baseVotingPower);
        }

        return ctx;
    }

    function onFlowUpdated(int96 previousFlowRate, int96 newFlowRate, bytes calldata ctx)
        internal
        virtual
        override
        returns (bytes memory newCtx)
    {
        if (newFlowRate != expectedFlowRate) {
            Council(council).removeCouncilMember(sender);
        }

        return ctx;
    }

    function onFlowDeleted(
        ISuperToken /*superToken*/,
        address /*sender*/,
        address /*receiver*/,
        int96 /*previousFlowRate*/,
        uint256 /*lastUpdated*/,
        bytes calldata ctx
    ) internal virtual returns (bytes memory /*newCtx*/) {
        Council(council).removeCouncilMember(sender);
        return ctx;
    }

    function setExpectedFlowRate(int96 _expectedFlowRate) public onlyOwner {
        expectedFlowRate = _expectedFlowRate;
    }

    function setCouncil(address _council) public onlyOwner {
        council = _council;
    }
}
