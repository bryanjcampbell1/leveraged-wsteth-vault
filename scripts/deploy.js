import { ethers } from "hardhat";

async function main() {
  const strategyManager = "0xAbc..123";
  const idealDebtToCollateral = 123;

  const vault = await ethers.deployContract("LeveragedWstEth");
  await vault.waitForDeployment();

  const strategy = await ethers.deployContract("AaveStrategy", [
    vault.target,
    strategyManager,
    idealDebtToCollateral,
  ]);

  await strategy.waitForDeployment();

  await (await vault.setStrategy(strategy.target)).wait();

  console.log("vault: ", vault.target);
  console.log("strategy: ", strategy.target);
}

// We recommend this pattern to be able to use async/await everywhere
// and properly handle errors.
main().catch((error) => {
  console.error(error);
  process.exitCode = 1;
});
