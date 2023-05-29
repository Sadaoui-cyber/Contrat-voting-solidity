// SPDX-License-Identifier: GPL-3.0

pragma solidity 0.8.15;

import "https://github.com/OpenZeppelin/openzeppelin-contracts/blob/master/contracts/access/Ownable.sol";

contract Voting is Ownable {
    // Structure de données pour représenter un électeur
    struct Voter {
        bool isRegistered;         
        bool hasVoted;             
        uint votedProposalId;      
    }

    // Structure de données pour représenter une proposition
    struct Proposal {
        string description;        
        uint voteCount;            
    }

    // Énumération pour gérer les différents états d'un vote
    enum WorkflowStatus {
        RegisteringVoters,
        ProposalsRegistrationStarted,
        ProposalsRegistrationEnded,
        VotingSessionStarted,
        VotingSessionEnded,
        VotesTallied
    }

    // Mapping pour stocker les électeurs
    mapping(address => Voter) private voters;

    // Tableau pour stocker les propositions
    Proposal[] public proposals;

    // État actuel du vote
    WorkflowStatus public workflowStatus;

    // ID de la proposition gagnante
    uint public winningProposalId;

    // Adresse de l'administrateur
    address public admin;

    // Événements
    event VoterRegistered(address voterAddress);
    event WorkflowStatusChange(WorkflowStatus previousStatus, WorkflowStatus newStatus);
    event ProposalRegistered(uint proposalId);
    event Voted(address voter, uint proposalId);

    // Constructeur du smart contract
    constructor() {
        workflowStatus = WorkflowStatus.RegisteringVoters;
        admin = msg.sender;
    }

    // Modificateur pour restreindre l'accès aux fonctions réservées à l'administrateur
    modifier onlyAdmin() {
        require(msg.sender == admin, "Seul l'administrateur peut effectuer cette action");
        _;
    }

    // Modificateur pour restreindre l'accès aux fonctions réservées aux électeurs inscrits
    modifier onlyRegisteredVoter() {
        require(voters[msg.sender].isRegistered, "Vous n'etes pas un electeur");
        _;
    }

    // Modificateur pour restreindre l'accès aux fonctions en fonction de l'état actuel du vote
    modifier onlyDuringStatus(WorkflowStatus _status) {
        require(workflowStatus == _status, "Statut de flux de travail non valide");
        _;
    }

    // Fonction permettant à l'administrateur d'enregistrer un électeur sur la liste blanche
    function registerVoter(address _voterAddress) external onlyAdmin onlyDuringStatus(WorkflowStatus.RegisteringVoters) {
        require(!voters[_voterAddress].isRegistered, "L'electeur est deja inscrit.");

        voters[_voterAddress].isRegistered = true;

        emit VoterRegistered(_voterAddress);
    }

    // Fonction permettant à l'administrateur de démarrer la session d'enregistrement des propositions
    function startProposalsRegistration() external onlyAdmin onlyDuringStatus(WorkflowStatus.RegisteringVoters) {
        workflowStatus = WorkflowStatus.ProposalsRegistrationStarted;

        emit WorkflowStatusChange(WorkflowStatus.RegisteringVoters, WorkflowStatus.ProposalsRegistrationStarted);
    }
     // Fonction permettant à l'administrateur de mettre fin à la session d'enregistrement des propositions
    function endProposalsRegistration() external onlyAdmin onlyDuringStatus(WorkflowStatus.ProposalsRegistrationStarted) {
        workflowStatus = WorkflowStatus.ProposalsRegistrationEnded;

        emit WorkflowStatusChange(WorkflowStatus.ProposalsRegistrationStarted, WorkflowStatus.ProposalsRegistrationEnded);
    }

    // Fonction permettant aux électeurs inscrits d'enregistrer une proposition
    function registerProposal(string memory _description) external onlyRegisteredVoter onlyDuringStatus(WorkflowStatus.ProposalsRegistrationStarted) {
        uint proposalId = proposals.length;

        proposals.push(Proposal({
            description: _description,
            voteCount: 0
        }));

        emit ProposalRegistered(proposalId);
    }

    // Fonction permettant à l'administrateur de démarrer la session de vote
    function startVotingSession() external onlyAdmin onlyDuringStatus(WorkflowStatus.ProposalsRegistrationEnded) {
        workflowStatus = WorkflowStatus.VotingSessionStarted;

        emit WorkflowStatusChange(WorkflowStatus.ProposalsRegistrationEnded, WorkflowStatus.VotingSessionStarted);
    }

    // Fonction permettant à l'administrateur de mettre fin à la session de vote
    function endVotingSession() external onlyAdmin onlyDuringStatus(WorkflowStatus.VotingSessionStarted) {
        workflowStatus = WorkflowStatus.VotingSessionEnded;

        emit WorkflowStatusChange(WorkflowStatus.VotingSessionStarted, WorkflowStatus.VotingSessionEnded);
    }

    // Fonction permettant aux électeurs inscrits de voter pour une proposition
    function vote(uint _proposalId) external onlyRegisteredVoter onlyDuringStatus(WorkflowStatus.VotingSessionStarted) {
        require(!voters[msg.sender].hasVoted, "Vous avez deja vote");
        require(_proposalId < proposals.length, "ID de proposition non valide.");

        voters[msg.sender].hasVoted = true;
        voters[msg.sender].votedProposalId = _proposalId;

        proposals[_proposalId].voteCount++;

        emit Voted(msg.sender, _proposalId);
    }

    // Fonction pour comptabiliser les votes et déterminer la proposition gagnante
    function tallyVotes() external onlyAdmin onlyDuringStatus(WorkflowStatus.VotingSessionEnded) {
        uint maxVoteCount = 0;
        uint winningId = 0;

        for (uint i = 0; i < proposals.length; i++) {
            if (proposals[i].voteCount > maxVoteCount) {
                maxVoteCount = proposals[i].voteCount;
                winningId = i;
            }
        }

        winningProposalId = winningId;
        workflowStatus = WorkflowStatus.VotesTallied;
    }

    // Fonction pour obtenir le gagnant du vote
    function getWinner() external view returns (uint) {
        require(workflowStatus == WorkflowStatus.VotesTallied, "Le depouillement des votes n'est pas encore termine");
        return winningProposalId;
    }

    // Fonction pour réinitialiser le contrat intelligent pour une nouvelle session de vote
    function resetVoting() external onlyAdmin {
        delete proposals;
        workflowStatus = WorkflowStatus.RegisteringVoters;
        winningProposalId = 0;
        admin = msg.sender;
    }
    }