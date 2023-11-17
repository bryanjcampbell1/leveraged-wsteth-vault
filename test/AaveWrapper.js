const {
  time,
  loadFixture,
} = require("@nomicfoundation/hardhat-toolbox/network-helpers");
const { anyValue } = require("@nomicfoundation/hardhat-chai-matchers/withArgs");
const { expect } = require("chai");


describe("AaveWrapper", function () {
  async function deployAaveWrapper() {
    const [owner, account1] = await ethers.getSigners();

    //Prepare tokens
    const wstEthAddress = "0x7f39C581F595B53c5cb19bD0b3f8dA6c935E2Ca0";
    const wstEth = await hre.ethers.getContractAt("IWstEth", wstEthAddress);

    //When sent directly, ETH is caught and converted to wstETH by receive()
    const wrap = await account1.sendTransaction({
      to: wstEthAddress,
      value: "1000000000000000000",
    });

    await wrap.wait();

    // Now you can call functions of the contract
    const bal = await wstEth.balanceOf(account1.address);

    const AaveWrapper = await ethers.getContractFactory("AaveWrapper");
    const aaveWrapper = await AaveWrapper.deploy();

    // Approve AaveWrapper to spend wstEth
    const approve = await wstEth
      .connect(account1)
      .approve(aaveWrapper.target, bal);
    await approve.wait();

    const supply = await aaveWrapper.connect(account1).supplyLeverage(bal);
    await supply.wait();

    const withdrawAll = await aaveWrapper.harvest();
    await withdrawAll.wait();

    return { aaveWrapper, owner, account1, wstEth };
  }

  // describe("Deployment", function () {
  //   it("Should deploy contracts", async function () {
  //     // const { aaveWrapper, owner, otherAccount, wstEth  } = await loadFixture(deployAaveWrapper);
  //     // expect(true).to.equal(true);
  //   });
  // });
});

// describe("AaveWrapper", function () {

//   async function deployAaveWrapper() {

//     const [owner, account1] = await ethers.getSigners();

//     //Prepare tokens 
//     const wstEthAddress = "0x7f39C581F595B53c5cb19bD0b3f8dA6c935E2Ca0"
//     const aWstEthAddress = "0x0B925eD163218f6662a35e0f0371Ac234f9E9371"

//     const wstEth = await hre.ethers.getContractAt("IERC20", wstEthAddress );
//     const aWstEth = await hre.ethers.getContractAt("IERC20", aWstEthAddress );
//     //const wstEth = await hre.ethers.getContractAt("IWstEth", wstEthAddress );

//     //When sent directly, ETH is caught and converted to wstETH by receive()
//     const wrap = await account1.sendTransaction({
//       to: wstEthAddress ,
//       value: "1000000000000000000"
//     });
    
//     await wrap.wait();

//     // Now you can call functions of the contract
//     const bal = await wstEth.balanceOf(account1.address)
//     console.log("bal: ", bal)

//     const AaveWrapper = await ethers.getContractFactory("AaveWrapper");
//     const aaveWrapper = await AaveWrapper.deploy();

//     console.log("aaveWrapper: ", aaveWrapper.target)

//     // Approve AaveWrapper to spend wstEth
//     const approve = await wstEth.connect(account1).approve(aaveWrapper.target, bal)
//     await approve.wait()

//     const abal = await aWstEth.balanceOf(account1.address)
//     console.log("aTok: ", abal)

//     const supply = await aaveWrapper.connect(account1).supply(wstEthAddress, bal)
//     await supply.wait()
    
//     const abal2 = await aWstEth.balanceOf(account1.address)
//     console.log("aTok: ", abal2)

    

//     return { aaveWrapper, owner, account1, wstEth, aWstEth };
//   }

//   describe("Deployment", function () {
//     it("Should deploy contracts", async function () {
//       const { aaveWrapper, owner, otherAccount, wstEth  } = await loadFixture(deployAaveWrapper);

//       expect(true).to.equal(true);
//     });
//   });


// });
