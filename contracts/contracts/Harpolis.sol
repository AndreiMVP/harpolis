// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import "./utils.sol";

enum Vote {
    NONE,
    ACCEPTED,
    REJECTED
}

struct Citizen {
    uint256 balance; // balance of citizen to pay for taxes
    uint256 pendingTax; // total pending tax that needs to be paid
    uint256 startTimestamp; // timestamp when citizen started acquired first property
    uint256 totalPropertyWorth; // sum of all properties valuations for calculating tax
    uint256 periodsOnLastUpdate; // tax periods collected
    mapping(uint256 => bool) properties; // properties owned by citizen
}

struct Property {
    address owner; // owner of property
    uint256 valuation; // valuation of property given by owner
}

struct Proposal {
    address creator; // creator of proposal
    address target; // the address the governence call is sent to; can be itself
    uint256 value; // funds to be used; can be zero
    uint256 creationTime; // time when proposal was created
    uint256 acceptVotes; // accepted proposal votes
    uint256 rejectVotes; // rejected proposal votes
    uint256 votingClosingTime; // time when voting finishes
    uint256 lastProcessedVoteIdx; // last processed vote index
    bytes data; // data to be sent in the call
    address[] voters; // list of voters who voted on the proposal
    mapping(address => Vote) votes; // mapping of voters to votes
}

contract Harpolis {
    // ===-===-=== DATA LAYOUT ===-===-===

    string public constant name = "Harpolis";

    string public constant symbol = "HAR";

    uint256 public constant TAX_COLLECTION_TIMEFRAME = 1 weeks;

    address public governor;

    uint256 public taxRate;

    uint256 public votingDuration;

    uint256 public executionDuration;

    mapping(address => Citizen) public citizens;

    mapping(uint256 => Property) public properties;

    uint256 public treasury;

    uint256 public totalSupply;

    mapping(uint256 => Proposal) public proposals;

    uint256 public proposalsCount;

    // ===-===-=== EVENTS ===-===-===

    event VoteCasted(address voter, uint256 proposalId, Vote vote);

    event ProposalCreated(
        address creator,
        uint256 proposalId,
        uint256 votingClosingTime,
        bytes data,
        address target,
        uint256 value
    );

    // ===-===-=== MODIFIER ===-===-===

    modifier onlyGovernance() {
        require(msg.sender == address(this), "Call must be through governance");
        _;
    }

    modifier onlyPropertyOwner(uint256 _propertyId) {
        require(
            properties[_propertyId].owner == msg.sender,
            "Caller must be owner of the property"
        );
        _;
    }

    modifier onlyCitizen(address _citizen) {
        require(
            citizens[_citizen].totalPropertyWorth > 0,
            "Caller must be citizen"
        );
        _;
    }

    modifier validProposal(uint256 _proposalId) {
        require(
            _proposalId > 0 && _proposalId <= proposalsCount,
            "Proposal must be valid"
        );
        _;
    }

    // ===-===-=== CONSTRUCTOR ===-===-===

    constructor(
        uint256 _votingDuration,
        address[] memory _seededOwners,
        uint256[] memory _seededPropertyIds,
        uint256[] memory _seededValuations
    ) {
        votingDuration = _votingDuration;
        treasury = 1000000;
        totalSupply = 1000000;

        for (uint256 i = 0; i < _seededOwners.length; i++) {
            address owner = _seededOwners[i];
            uint256 propertyId = _seededPropertyIds[i];
            uint256 valuation = _seededValuations[i];

            Property storage property = properties[propertyId];
            property.owner = owner;
            property.valuation = valuation;

            Citizen storage citizen = citizens[owner];
            citizen.startTimestamp = block.timestamp;
            citizen.totalPropertyWorth += valuation;
            citizen.properties[propertyId] = true;
        }
    }

    // ===-===-=== GOVERNANCE ===-===-===

    function changeTaxRate(uint256 _taxRate) public onlyGovernance {
        require(_taxRate < 100);
        taxRate = _taxRate;
    }

    function mintProperty(uint256 _propertyId, uint256 _startValuation)
        external
        onlyGovernance
    {
        Property storage property = properties[_propertyId];
        require(property.owner == address(0x0), "Property already minted");

        property.owner = address(this);
        property.valuation = _startValuation;
    }

    function burnProperty(uint256 _propertyId) external onlyGovernance {
        address owner = ownerOf(_propertyId);

        updatePendingTaxes(owner);

        Citizen storage citizen = citizens[owner];
        Property storage property = properties[_propertyId];

        citizen.properties[_propertyId] = false;
        citizen.totalPropertyWorth -= property.valuation;

        delete property.owner;
        delete property.valuation;
    }

    function changeVotingDuration(uint256 _votingDuration)
        public
        onlyGovernance
    {
        votingDuration = _votingDuration;
    }

    function changeExecutionDuration(uint256 _executionDuration)
        public
        onlyGovernance
    {
        executionDuration = _executionDuration;
    }

    // ===-===-=== STATE CHANGES ===-===-===

    function addBalance() external payable {
        citizens[msg.sender].balance += msg.value;
    }

    function buyProperty(uint256 _propertyId, uint256 _newValuation) external {
        address prevOwner = ownerOf(_propertyId);
        require(prevOwner != msg.sender, "Can't buy own property");

        Citizen storage citizen = citizens[msg.sender];
        if (citizen.startTimestamp != 0) {
            require(
                payTaxes(msg.sender),
                "Must have no pending taxes at the moment of buying a property"
            );
            citizen.startTimestamp = block.timestamp;
        }

        updatePendingTaxes(prevOwner);

        Property storage property = properties[_propertyId];

        citizens[prevOwner].properties[_propertyId] = false;
        citizens[prevOwner].totalPropertyWorth -= property.valuation;

        citizen.properties[_propertyId] = true;
        citizen.totalPropertyWorth += _newValuation;

        property.owner = msg.sender;
        property.valuation = _newValuation;
    }

    function updateValuation(uint256 _propertyId, uint256 _valuation)
        external
        onlyPropertyOwner(_propertyId)
    {
        require(
            payTaxes(msg.sender),
            "Must have no pending taxes at the moment of valuation update"
        );
        Citizen storage citizen = citizens[msg.sender];
        Property storage property = properties[_propertyId];

        citizen.totalPropertyWorth -= property.valuation;
        citizen.totalPropertyWorth += _valuation;
        property.valuation = _valuation;
    }

    function payTaxes(address _citizen) public returns (bool fullyPaid) {
        uint256 taxesDue = updatePendingTaxes(_citizen);
        if (taxesDue == 0) return true;
        Citizen storage citizen = citizens[_citizen];

        uint256 toBePaid;
        if (citizen.balance >= taxesDue) {
            toBePaid = taxesDue;
            fullyPaid = true;
        } else toBePaid = citizen.balance;

        citizen.balance -= toBePaid;
        treasury += toBePaid;
    }

    function updatePendingTaxes(address _citizen)
        public
        returns (uint256 newPendingTaxes)
    {
        newPendingTaxes = currentPendingTaxes(_citizen);
        Citizen storage citizen = citizens[_citizen];
        citizen.pendingTax += newPendingTaxes;
        citizen.periodsOnLastUpdate = _periodsSinceCitizenshipStarted(_citizen);
    }

    function createProposal(
        bytes calldata _data,
        address _target,
        uint256 _value
    ) external onlyCitizen(msg.sender) {
        Proposal storage proposal = proposals[++proposalsCount];

        proposal.creator = msg.sender;
        proposal.creationTime = block.timestamp;

        proposal.data = _data;
        proposal.target = _target;
        proposal.value = _value;

        uint256 votingClosingTime = block.timestamp + votingDuration;
        proposal.votingClosingTime = votingClosingTime;

        emit ProposalCreated(
            msg.sender,
            proposalsCount,
            votingClosingTime,
            _data,
            _target,
            _value
        );
    }

    function castVote(uint256 _proposalId, Vote _vote)
        external
        validProposal(_proposalId)
        onlyCitizen(msg.sender)
    {
        require(_vote != Vote.NONE, "Vote cannot be NONE");

        Proposal storage proposal = proposals[_proposalId];

        require(
            block.timestamp <= proposal.votingClosingTime,
            "Voting time passed"
        );
        require(
            proposal.votes[msg.sender] == Vote.NONE,
            "User already voted on this proposal"
        );

        proposal.votes[msg.sender] = _vote;
        proposal.voters.push(msg.sender);

        emit VoteCasted(msg.sender, _proposalId, _vote);
    }

    function countVotes(uint256 _proposalId, uint256 _iterations) external {
        Proposal storage proposal = proposals[_proposalId];
        require(
            block.timestamp > proposal.votingClosingTime,
            "Voting time has not passed"
        );

        uint256 endIndex = proposal.lastProcessedVoteIdx + _iterations;
        uint256 numberOfVotes = proposal.voters.length;
        if (endIndex > numberOfVotes) endIndex = numberOfVotes;

        (uint256 acceptVotes, uint256 rejectVotes) = (0, 0);
        for (uint256 i = 0; i < endIndex; i++) {
            address voter = proposal.voters[i];
            Vote vote = proposal.votes[voter];

            uint256 weight = sqrt(citizens[voter].totalPropertyWorth);

            if (vote == Vote.ACCEPTED) acceptVotes += weight;
            else rejectVotes += weight;
        }

        proposal.acceptVotes += acceptVotes;
        proposal.rejectVotes += rejectVotes;
    }

    function executeProposal(uint256 _proposalId) external {
        Proposal storage proposal = proposals[_proposalId];
        require(
            block.timestamp > proposal.votingClosingTime,
            "Voting time has not passed"
        );
        require(
            proposal.lastProcessedVoteIdx >= proposal.voters.length,
            "Not all votes counted"
        );
        require(
            proposal.creationTime < block.timestamp + executionDuration,
            "Proposal has expired"
        );
        (bool success, ) = proposal.target.call{value: proposal.value}(
            proposal.data
        );
        require(success);
    }

    // ===-===-=== VIEWS ===-===-===

    function isPublicProperty(uint256 _propertyId) public view returns (bool) {
        return properties[_propertyId].owner == msg.sender;
    }

    function currentPendingTaxes(address _citizen)
        public
        view
        returns (uint256)
    {
        Citizen storage citizen = citizens[_citizen];
        return
            citizen.totalPropertyWorth *
            (_periodsSinceCitizenshipStarted(_citizen) -
                citizen.periodsOnLastUpdate) *
            (taxRate / 100);
    }

    function _periodsSinceCitizenshipStarted(address _citizen)
        internal
        view
        onlyCitizen(_citizen)
        returns (uint256)
    {
        return
            (block.timestamp - citizens[_citizen].startTimestamp) /
            TAX_COLLECTION_TIMEFRAME;
    }

    function realBalance(address _citizen) public view returns (uint256) {
        uint256 pendingTaxes = currentPendingTaxes(_citizen);
        return
            pendingTaxes < citizens[_citizen].balance
                ? citizens[_citizen].balance - pendingTaxes
                : 0;
    }

    function ownerOf(uint256 propertyId) public view returns (address owner) {
        owner = properties[propertyId].owner;
        require(owner != address(0), "Harpolis: invalid property ID");
    }
}
