import { ethers, upgrades, network } from "hardhat";

async function main() {
  const [owner] = await ethers.getSigners();
  const DexaCreator = await ethers.getContractFactory("DexaCreator");
  console.log("Upgrading DexaCreator...");
  const dexaCreator = await upgrades.upgradeProxy(
    "0x37734D64EcF9c21e423D33BD53c6623Dc9b31cf9",
    DexaCreator
  );
  await dexaCreator.waitForDeployment();
  const dexaCreatorAddr = await dexaCreator.getAddress();
  console.log("DexaCreator upgraded to:", dexaCreatorAddr);

  const DexaFeeds = await ethers.getContractFactory("DexaFeeds");
  console.log("Upgrading DexaFeeds...");
  const dexaFeeds = await upgrades.upgradeProxy(
    "0xAF4B035D79a0f77641ccA29396FfCE5de8C4FD95",
    DexaFeeds
  );
  await dexaFeeds.waitForDeployment();
  console.log("DexaFeeds upgraded to:", await dexaFeeds.getAddress());

  // const DexaStorage = await ethers.getContractFactory("DexaStorage");
  // console.log("Upgrading DexaStorage...");
  // const dexaStorage = await upgrades.upgradeProxy(
  //   "0x3F0Ff5505b6425715Cb9b68649942E103DC28D0f",
  //   DexaStorage
  // );
  // await dexaStorage.waitForDeployment();
  // console.log("DexaStorage upgraded to:", await dexaStorage.getAddress());
}

// We recommend this pattern to be able to use async/await everywhere
// and properly handle errors.
main().catch((error) => {
  console.error(error);
  process.exitCode = 1;
});
