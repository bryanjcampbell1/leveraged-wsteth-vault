const {
  loadFixture,
} = require("@nomicfoundation/hardhat-toolbox/network-helpers");
const { expect } = require("chai");

describe("LeveragedWstEth - AaveStrategy", function () {
  async function deployContracts() {
    const [owner, manager, user, otherUser] = await ethers.getSigners();

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

    const idealDebtToCollateral = 325; // (D/C) = 0.325
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

    return { owner, manager, user, wstEth, vault, strategy, otherUser };
  }

  async function deposit(contract, signer, amountInEthUnits) {
    expect(
      await contract
        .connect(signer)
        .deposit(BigInt(amountInEthUnits * 10 ** 18), signer.address)
    ).to.not.be.reverted;
  }

  describe("Deploy", function () {
    it("Should set correct strategy", async function () {
      const { vault, strategy } = await loadFixture(deployContracts);
      expect(await vault.strategy()).to.equal(strategy.target);
    });

    it("Should set correct manager", async function () {
      const { manager, strategy } = await loadFixture(deployContracts);
      expect(await strategy.manager()).to.equal(manager.address);
    });

    it("Should set correct asset", async function () {
      const { wstEth, vault } = await loadFixture(deployContracts);
      expect(await vault.asset()).to.equal(wstEth.target);
    });
  });

  describe("Deposits", function () {
    it("Shouldn't fail during deposit", async function () {
      const { user, vault } = await loadFixture(deployContracts);
      deposit(vault, user, 1);
    });

    it("Shouldn't fail during multiple deposits", async function () {
      const { user, vault } = await loadFixture(deployContracts);
      deposit(vault, user, 1);
      deposit(vault, user, 1);
    });
  });

  describe("Withdrawal", function () {
    it("Shouldn't fail during withdrawal", async function () {
      const { user, vault } = await loadFixture(deployContracts);
      deposit(vault, user, 2);

      expect(
        await vault
          .connect(user)
          .withdraw(BigInt(10 ** 18), user.address, user.address)
      ).to.not.be.reverted;
    });
  });

  describe("Redeem", function () {
    it("Shouldn't fail during redeem", async function () {
      const { user, vault } = await loadFixture(deployContracts);
      deposit(vault, user, 1);

      const shares = await vault.balanceOf(user);

      // redeem total balance
      expect(
        await vault.connect(user).redeem(shares, user.address, user.address)
      ).to.not.be.reverted;
    });
  });

  describe("Admin and Manager", function () {
    it("Admin sets new manager", async function () {
      const { strategy, otherUser } = await loadFixture(deployContracts);
      await strategy.setManager(otherUser.address);
      expect(await strategy.manager()).to.equal(otherUser.address);
    });

    it("Manager resets idealDebtToCollateral and calls harvest()", async function () {
      const { manager, user, vault, strategy } = await loadFixture(
        deployContracts
      );

      deposit(vault, user, 1);

      await (await strategy.connect(manager).setDebtToCollateral(200)).wait();
      expect(await strategy.idealDebtToCollateral()).to.equal(200);
      expect(await await strategy.connect(manager).harvest()).to.not.be
        .reverted;
    });

    it("Owner pauses contract and prevents deposits", async function () {
      const { user, vault } = await loadFixture(deployContracts);
      deposit(vault, user, 1);

      await (await vault.pause()).wait();

      await expect(vault.connect(user).deposit(BigInt(10 ** 18), user.address))
        .to.be.reverted;
    });
  });
});
