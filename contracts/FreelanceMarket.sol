// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import "@openzeppelin/contracts/security/ReentrancyGuard.sol";
import "@openzeppelin/contracts/access/Ownable.sol";
import "@openzeppelin/contracts/security/Pausable.sol";

contract FreelanceMarket is ReentrancyGuard, Ownable, Pausable {
    enum JobStatus { Open, InProgress, Completed, Disputed, Cancelled }

    struct Job {
        address client;
        address freelancer;
        string title;
        string description;
        uint256 budget;
        JobStatus status;
        uint256 createdAt;
        uint256 completedAt;
    }

    Job[] public jobs;
    mapping(address => uint256[]) public clientJobs;
    mapping(address => uint256[]) public freelancerJobs;
    
    uint256 public platformFee = 250; // 2.5%
    uint256 public constant FEE_DENOMINATOR = 10000;
    uint256 public totalJobsCompleted;
    uint256 public totalValueLocked;

    event JobCreated(uint256 indexed jobId, address indexed client, string title, uint256 budget);
    event JobAccepted(uint256 indexed jobId, address indexed freelancer);
    event JobCompleted(uint256 indexed jobId, uint256 payout);
    event JobCancelled(uint256 indexed jobId);
    event JobDisputed(uint256 indexed jobId);
    event DisputeResolved(uint256 indexed jobId, address winner);

    constructor() Ownable() {}

    function createJob(string calldata _title, string calldata _description) external payable whenNotPaused {
        require(msg.value > 0, "Budget required");
        require(bytes(_title).length > 0, "Title required");

        uint256 jobId = jobs.length;
        jobs.push(Job({
            client: msg.sender,
            freelancer: address(0),
            title: _title,
            description: _description,
            budget: msg.value,
            status: JobStatus.Open,
            createdAt: block.timestamp,
            completedAt: 0
        }));
        
        clientJobs[msg.sender].push(jobId);
        totalValueLocked += msg.value;
        emit JobCreated(jobId, msg.sender, _title, msg.value);
    }

    function acceptJob(uint256 _jobId) external whenNotPaused {
        Job storage job = jobs[_jobId];
        require(job.status == JobStatus.Open, "Job not open");
        require(msg.sender != job.client, "Client cannot accept own job");

        job.freelancer = msg.sender;
        job.status = JobStatus.InProgress;
        freelancerJobs[msg.sender].push(_jobId);
        emit JobAccepted(_jobId, msg.sender);
    }

    function approveWork(uint256 _jobId) external nonReentrant whenNotPaused {
        Job storage job = jobs[_jobId];
        require(msg.sender == job.client, "Only client");
        require(job.status == JobStatus.InProgress, "Not in progress");

        job.status = JobStatus.Completed;
        job.completedAt = block.timestamp;
        totalJobsCompleted++;
        
        uint256 fee = (job.budget * platformFee) / FEE_DENOMINATOR;
        uint256 payout = job.budget - fee;
        totalValueLocked -= job.budget;

        (bool sent,) = job.freelancer.call{value: payout}("");
        require(sent, "Payment failed");
        emit JobCompleted(_jobId, payout);
    }

    function cancelJob(uint256 _jobId) external nonReentrant whenNotPaused {
        Job storage job = jobs[_jobId];
        require(msg.sender == job.client, "Only client");
        require(job.status == JobStatus.Open, "Can only cancel open jobs");

        job.status = JobStatus.Cancelled;
        totalValueLocked -= job.budget;
        (bool sent,) = job.client.call{value: job.budget}("");
        require(sent, "Refund failed");
        emit JobCancelled(_jobId);
    }

    function raiseDispute(uint256 _jobId) external whenNotPaused {
        Job storage job = jobs[_jobId];
        require(job.status == JobStatus.InProgress, "Not in progress");
        require(msg.sender == job.client || msg.sender == job.freelancer, "Not party");
        job.status = JobStatus.Disputed;
        emit JobDisputed(_jobId);
    }

    function resolveDispute(uint256 _jobId, bool _favorFreelancer) external onlyOwner nonReentrant {
        Job storage job = jobs[_jobId];
        require(job.status == JobStatus.Disputed, "Not disputed");

        job.status = JobStatus.Completed;
        job.completedAt = block.timestamp;
        totalValueLocked -= job.budget;

        address winner = _favorFreelancer ? job.freelancer : job.client;
        uint256 amount = _favorFreelancer ? job.budget - (job.budget * platformFee / FEE_DENOMINATOR) : job.budget;
        if (_favorFreelancer) totalJobsCompleted++;

        (bool sent,) = winner.call{value: amount}("");
        require(sent, "Transfer failed");
        emit DisputeResolved(_jobId, winner);
    }

    function getJob(uint256 _jobId) external view returns (Job memory) { return jobs[_jobId]; }
    function getJobCount() external view returns (uint256) { return jobs.length; }
    function getClientJobs(address _client) external view returns (uint256[] memory) { return clientJobs[_client]; }
    function getFreelancerJobs(address _freelancer) external view returns (uint256[] memory) { return freelancerJobs[_freelancer]; }
    function setPlatformFee(uint256 _fee) external onlyOwner { require(_fee <= 1000, "Max 10%"); platformFee = _fee; }
    function withdrawFees() external onlyOwner { (bool sent,) = owner().call{value: address(this).balance - totalValueLocked}(""); require(sent); }
    function pause() external onlyOwner { _pause(); }
    function unpause() external onlyOwner { _unpause(); }
}
