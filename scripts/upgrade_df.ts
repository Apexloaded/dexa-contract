import { ethers, upgrades, network } from "hardhat";

async function main() {
//   const [owner] = await ethers.getSigners();
//   const DexaFeeds = await ethers.getContractFactory("DexaFeeds");
//   console.log("Upgrading DexaFeeds...");
//   const dexaFeeds = await upgrades.upgradeProxy(
//     "0x3CACDf318a568a0d73e3D25C8A4870FD1D7b64dC",
//     DexaFeeds
//   );
//   await dexaFeeds.waitForDeployment();
//   console.log("DexaFeeds upgraded to:", await dexaFeeds.getAddress());

  // const DexaMessenger = await ethers.getContractFactory("DexaMessenger");
  // console.log("Upgrading DexaMessenger...");
  // const dexaMessenger = await upgrades.upgradeProxy(
  //   "0xF0E4EFad3942198a17B358aA79bD5FC7bd666504",
  //   DexaMessenger
  // );
  // await dexaMessenger.waitForDeployment();
  // console.log("DexaMessenger upgraded to:", await dexaMessenger.getAddress());

    const DexaCreator = await ethers.getContractFactory("DexaCreator");
    console.log("Upgrading DexaCreator...");
    const dexaCreator = await upgrades.upgradeProxy(
      "0xb1978d2c929C808dFA7b3B79730B761446458581",
      DexaCreator
    );
    await dexaCreator.waitForDeployment();
    console.log("DexaCreator upgraded to:", await dexaCreator.getAddress());
    // await dexaCreator.setCreators([
    //   "0x719c1A5dac69C4C6b462Aa7E8Fb9bc90Ec9128b9",
    //   "0xB88d60D5454d449C38084c4780711A76fCA9eD68",
    //   "0x4279D2C384bFD8c226bCCA79653b5398646c43b9",
    // ]);

  //   const FeedsToken = await ethers.getContractFactory("FeedsToken");
  //   console.log("Upgrading FeedsToken...");
  //   const feedsToken = await upgrades.upgradeProxy(
  //     "0x32bF594b5002eEF18C164F4340756CF68A697aa3",
  //     FeedsToken
  //   );
  //   await feedsToken.waitForDeployment();
  //   const uriTx = await feedsToken.setTokenURI(
  //     "https://gnfd-testnet-sp1.bnbchain.org/view/dexa/metadata/{id}.json"
  //   );
  //   uriTx.wait(3);
  //   const feedsTokenAddr = await feedsToken.getAddress();
  //   console.log("FeedsToken upgraded to:", feedsTokenAddr);
}

// We recommend this pattern to be able to use async/await everywhere
// and properly handle errors.
main().catch((error) => {
  console.error(error);
  process.exitCode = 1;
});
