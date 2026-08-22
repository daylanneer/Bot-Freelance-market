const hre = require("hardhat");
async function main() {
  const [deployer] = await hre.ethers.getSigners();
  console.log("Deploying FreelanceMarket with account:", deployer.address);
  const FreelanceMarket = await hre.ethers.getContractFactory("FreelanceMarket");
  const market = await FreelanceMarket.deploy();
  await market.waitForDeployment();
  const addr = await market.getAddress();
  console.log("FreelanceMarket deployed to:", addr);
  console.log("View on explorer: https://scan.botchain.ai/address/" + addr);
}
main().catch((e) => { console.error(e); process.exitCode = 1; });
