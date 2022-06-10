// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

contract QVVoting {
    event VoteCasted(address voter, uint256 proposalId, Vote vote);

    event ProposalCreated(
        address creator,
        uint256 proposalId,
        uint256 expirationTime,
        bytes data
    );

    enum Vote {
        NONE,
        ACCEPTED,
        REJECTED
    }

    struct Proposal {
        address creator;
        uint256 acceptVotes;
        uint256 rejectVotes;
        uint256 expirationTime;
        bytes data;
        address[] voters;
        mapping(address => Vote) votes;
    }

    uint256 votingDuration = 1 weeks;

    mapping(uint256 => Proposal) public proposals;

    uint256 public proposalsCount;

    modifier validProposal(uint256 _proposalId) {
        require(
            _proposalId > 0 && _proposalId <= proposalsCount,
            "Not a valid Proposal Id"
        );
        _;
    }

    function createProposal(bytes calldata _data) external returns (uint256) {
        Proposal storage curProposal = proposals[++proposalsCount];
        curProposal.creator = msg.sender;

        uint256 expirationTime = block.timestamp + votingDuration;
        curProposal.expirationTime = expirationTime;
        curProposal.data = _data;

        emit ProposalCreated(msg.sender, proposalsCount, expirationTime, _data);
        return proposalsCount;
    }

    function countVotes(uint256 _proposalId)
        public
        view
        returns (uint256 acceptVotes, uint256 rejectVotes)
    {
        address[] memory voters = proposals[_proposalId].voters;
        for (uint256 i = 0; i < voters.length; i++) {
            address voter = voters[i];
            Vote vote = proposals[_proposalId].votes[voter];
            // TODO uint256 weight = proposals[_proposalId].voterInfo[voter].weight;
            if (vote == Vote.ACCEPTED)
                acceptVotes += 1; // weight;
            else rejectVotes += 1; // weight;
        }
    }

    function castVote(uint256 _proposalId, Vote _vote)
        external
        validProposal(_proposalId)
    {
        require(_vote == Vote.NONE, "vote cannot be NONE");

        Proposal storage proposal = proposals[_proposalId];

        require(
            block.timestamp < proposal.expirationTime,
            "proposal has expired."
        );
        require(
            proposal.votes[msg.sender] == Vote.NONE,
            "user already voted on this proposal"
        );

        // TODO: add balance uint256 weight = sqrt(100);

        proposal.votes[msg.sender] = _vote;
        proposal.voters.push(msg.sender);

        emit VoteCasted(msg.sender, _proposalId, _vote);
    }

    function sqrt(uint256 x) internal pure returns (uint256 y) {
        uint256 z = (x + 1) / 2;
        y = x;
        while (z < y) {
            y = z;
            z = (x / z + z) / 2;
        }
    }
}
