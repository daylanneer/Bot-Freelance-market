const { expect } = require("chai");
const { ethers } = require("hardhat");

describe("FreelanceMarket", function () {
  let market, owner, client, freelancer;
  beforeEach(async () => {
    [owner, client, freelancer] = await ethers.getSigners();
    const F = await ethers.getContractFactory("FreelanceMarket");
    market = await F.deploy();
  });

  it("should create a job", async () => {
    await market.connect(client).createJob("Build DApp", "Full stack", { value: ethers.parseEther("1") });
    const job = await market.getJob(0);
    expect(job.title).to.equal("Build DApp");
    expect(job.budget).to.equal(ethers.parseEther("1"));
  });

  it("should reject zero budget", async () => {
    await expect(market.connect(client).createJob("Test", "Desc", { value: 0 })).to.be.revertedWith("Budget required");
  });

  it("should accept a job", async () => {
    await market.connect(client).createJob("Task", "Do it", { value: ethers.parseEther("1") });
    await market.connect(freelancer).acceptJob(0);
    const job = await market.getJob(0);
    expect(job.freelancer).to.equal(freelancer.address);
    expect(job.status).to.equal(1);
  });

  it("should prevent client from accepting own job", async () => {
    await market.connect(client).createJob("Task", "Do it", { value: ethers.parseEther("1") });
    await expect(market.connect(client).acceptJob(0)).to.be.revertedWith("Client cannot accept own job");
  });

  it("should approve and pay freelancer", async () => {
    await market.connect(client).createJob("Task", "Do it", { value: ethers.parseEther("1") });
    await market.connect(freelancer).acceptJob(0);
    const balBefore = await ethers.provider.getBalance(freelancer.address);
    await market.connect(client).approveWork(0);
    const balAfter = await ethers.provider.getBalance(freelancer.address);
    expect(balAfter).to.be.gt(balBefore);
  });

  it("should cancel open job and refund", async () => {
    await market.connect(client).createJob("Task", "Do it", { value: ethers.parseEther("1") });
    await market.connect(client).cancelJob(0);
    const job = await market.getJob(0);
    expect(job.status).to.equal(4);
  });

  it("should raise dispute", async () => {
    await market.connect(client).createJob("Task", "Do it", { value: ethers.parseEther("1") });
    await market.connect(freelancer).acceptJob(0);
    await market.connect(client).raiseDispute(0);
    const job = await market.getJob(0);
    expect(job.status).to.equal(3);
  });

  it("should resolve dispute", async () => {
    await market.connect(client).createJob("Task", "Do it", { value: ethers.parseEther("1") });
    await market.connect(freelancer).acceptJob(0);
    await market.connect(client).raiseDispute(0);
    await market.resolveDispute(0, true);
    const job = await market.getJob(0);
    expect(job.status).to.equal(2);
  });

  it("should track client jobs", async () => {
    await market.connect(client).createJob("Job1", "Desc", { value: ethers.parseEther("1") });
    await market.connect(client).createJob("Job2", "Desc", { value: ethers.parseEther("2") });
    const ids = await market.getClientJobs(client.address);
    expect(ids.length).to.equal(2);
  });

  it("should update platform fee", async () => {
    await market.setPlatformFee(500);
    expect(await market.platformFee()).to.equal(500);
  });

  it("should pause and unpause", async () => {
    await market.pause();
    await expect(market.connect(client).createJob("T", "D", { value: ethers.parseEther("1") })).to.be.reverted;
    await market.unpause();
    await market.connect(client).createJob("T", "D", { value: ethers.parseEther("1") });
  });
});
