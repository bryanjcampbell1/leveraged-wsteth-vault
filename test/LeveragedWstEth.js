const {
  time,
  loadFixture,
} = require("@nomicfoundation/hardhat-toolbox/network-helpers");
const { anyValue } = require("@nomicfoundation/hardhat-chai-matchers/withArgs");
const { expect } = require("chai");

describe("LeveragedWstEth - AaveStrategy", function () {
  async function prepAccountsAndDeploy() {
    const [owner, manager, user] = await ethers.getSigners();

    const wstEthAddress = "0x7f39C581F595B53c5cb19bD0b3f8dA6c935E2Ca0";
    const wstEth = await hre.ethers.getContractAt("IWstEth", wstEthAddress);

    // User sends 10 ETH to wstEth contract and is returned wstEth by receive()
    await (
      await user.sendTransaction({
        to: wstEthAddress,
        value: BigInt(10 ** 19),
      })
    ).wait();

    // Deploy Vault and Strategy
    const LeveragedWstEth = await ethers.getContractFactory("LeveragedWstEth");
    const vault = await LeveragedWstEth.deploy();

    const idealDebtToCollateral = 225; // (D/C) = 0.225
    const AaveStrategy = await ethers.getContractFactory("AaveStrategy");
    const strategy = await AaveStrategy.deploy(
      vault.target,
      manager.address,
      idealDebtToCollateral
    );

    // Set vault strategy
    await vault.setStrategy(strategy.target);

    // User approves vault to spend wstEth
    const bal = await wstEth.balanceOf(user.address);
    const approve = await wstEth.connect(user).approve(vault.target, bal);
    await approve.wait();

    return { owner, manager, user, wstEth, vault, strategy };
  }

  describe("Deploy", function () {
    it("Should set correct strategy", async function () {
      const { owner, manager, user, wstEth, vault, strategy } =
        await loadFixture(prepAccountsAndDeploy);

      expect(await vault.strategy()).to.equal(strategy.target);
    });

    it("Should set correct manager", async function () {
      const { owner, manager, user, wstEth, vault, strategy } =
        await loadFixture(prepAccountsAndDeploy);

      expect(await strategy.manager()).to.equal(manager.address);
    });
  });

  describe("Deposits", function () {
    it("Shouldn't fail during deposit", async function () {
      const { owner, manager, user, wstEth, vault, strategy } =
        await loadFixture(prepAccountsAndDeploy);

      expect(await vault.connect(user).deposit(BigInt(10 ** 18), user.address))
        .to.not.be.reverted;
    });

    it("Shouldn't fail during multiple deposits", async function () {
      const { owner, manager, user, wstEth, vault, strategy } =
        await loadFixture(prepAccountsAndDeploy);

      expect(await vault.connect(user).deposit(BigInt(10 ** 18), user.address))
        .to.not.be.reverted;

      expect(await vault.connect(user).deposit(BigInt(10 ** 18), user.address))
        .to.not.be.reverted;
    });
  });

  describe("Withdrawals", function () {
    it("Shouldn't fail during withdrawal", async function () {
      const { owner, manager, user, wstEth, vault, strategy } =
        await loadFixture(prepAccountsAndDeploy);

        expect(
          await vault.connect(user).deposit(BigInt(2 * 10 ** 18), user.address)
        ).to.not.be.reverted;

        console.log("preview: ", await vault.previewWithdraw(BigInt(10 ** 18)));

        expect(
          await vault
            .connect(user)
            .withdraw(BigInt(10 ** 18), user.address, user.address)
        ).to.not.be.reverted;

    });
  });
});

// const supply = await aaveWrapper.connect(account1).supplyLeverage(bal);
// await supply.wait();

// const withdrawAll = await aaveWrapper.harvest();
// await withdrawAll.wait();
