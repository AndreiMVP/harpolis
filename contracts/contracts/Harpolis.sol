// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import "./interfaces/IERC721.sol";
import "./Governable.sol";

contract Harpolis {
    // === === === DATA LAYOUT === === ===

    string public constant name = "HarPolis";
    string public constant symbol = "HAR";

    uint256 public constant TAX_COLLECTION_TIMEFRAME = 1 weeks;

    struct Citizen {
        uint256 balance; // balance of citizen to pay for taxes
        uint256 pendingTax; // total pending tax that needs to be paid
        uint256 startTimestamp; // timestamp when citizen started acquired first property
        uint256 totalPropertyWorth; // sum of all properties valuations for calculating tax
        uint256 periodsOnLastUpdate; // tax periods collected
        mapping(uint256 => bool) properties; // properties owned by citizen
    }

    address public governor;

    uint256 public taxRate;

    mapping(address => Citizen) public citizens;
    mapping(uint256 => address) public owners;
    mapping(uint256 => uint256) public valuations;

    // === === === EVENTS === === ===

    event GovernanceTransferred(
        address indexed previousGovernor,
        address indexed newGovernor
    );

    // === === === MODIFIER === === ===

    modifier onlyGovernor() {
        require(governor == msg.sender, "Caller is not the Governor");
        _;
    }

    modifier onlyPropertyOwner(uint256 _propertyId) {
        require(owners[_propertyId] == msg.sender);
        _;
    }

    modifier onlyCitizen(address _citizen) {
        require(citizens[_citizen].startTimestamp > 0);
        _;
    }

    // === === === CONSTRUCTOR === === ===

    constructor() {
        _transferGovernance(msg.sender);
    }

    // === === === GOVERNOR === === ===

    function initializeAnarchy() public onlyGovernor {
        _transferGovernance(address(0));
    }

    function transferGovernance(address newGovernor) public onlyGovernor {
        require(newGovernor != address(0), "New Governor is the zero address");
        _transferGovernance(newGovernor);
    }

    function _transferGovernance(address newGovernor) internal {
        address oldGovernor = governor;
        governor = newGovernor;
        emit GovernanceTransferred(oldGovernor, newGovernor);
    }

    function changeTaxRate(uint256 _taxRate) public onlyGovernor {
        require(_taxRate < 100);
        taxRate = _taxRate;
    }

    function mintProperty(uint256 _propertyId, uint256 _startValuation)
        external
        onlyGovernor
    {
        require(owners[_propertyId] == address(0x0), "Property already minted");

        owners[_propertyId] = governor;
        valuations[_propertyId] = _startValuation;
    }

    function burnProperty(uint256 _propertyId) external onlyGovernor {
        address owner = ownerOf(_propertyId);

        updatePendingTaxes(owner);

        Citizen storage citizen = citizens[owner];
        citizen.properties[_propertyId] = false;
        citizen.totalPropertyWorth -= valuations[_propertyId];

        delete owners[_propertyId];
        delete valuations[_propertyId];
    }

    // === === === STATE CHANGES === === ===

    function addBalance() public payable {
        citizens[msg.sender].balance += msg.value;
    }

    function buyProperty(uint256 _propertyId, uint256 _newValuation) public {
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

        citizens[prevOwner].properties[_propertyId] = false;
        citizens[prevOwner].totalPropertyWorth -= valuations[_propertyId];

        citizen.properties[_propertyId] = true;
        citizen.totalPropertyWorth += _newValuation;

        owners[_propertyId] = msg.sender;
        valuations[_propertyId] = _newValuation;
    }

    function updateValuation(uint256 _propertyId, uint256 _valuation)
        public
        onlyPropertyOwner(_propertyId)
    {
        require(
            payTaxes(msg.sender),
            "Must have no pending taxes at the moment of valuation update"
        );
        Citizen storage citizen = citizens[msg.sender];
        citizen.totalPropertyWorth -= valuations[_propertyId];
        citizen.totalPropertyWorth += _valuation;
        valuations[_propertyId] = _valuation;
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

        (bool success, ) = governor.call{value: toBePaid}("");
        require(success);
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

    // === === === VIEWS === === ===

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
        owner = owners[propertyId];
        require(owner != address(0), "Harpolis: invalid property ID");
    }
}
