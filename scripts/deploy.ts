import { ethers, upgrades, network } from "hardhat";

// USDT testnet : 0x337610d27c682E347C9cD60BD4b3b107C9d34dDd
// Decoin : 0x2fC661046c3365ecb408a491F14828eA90587304

async function main() {
  const [owner] = await ethers.getSigners();
  const FeedsToken = await ethers.getContractFactory("FeedsToken");
  console.log("Deploying FeedsToken...");
  const feedsToken = await upgrades.deployProxy(FeedsToken, [owner.address], {
    initializer: "init_feed_token",
    initialOwner: owner.address,
  });
  await feedsToken.waitForDeployment();
  const feedsTokenAddr = await feedsToken.getAddress();
  console.log("FeedsToken deployed to:", feedsTokenAddr);

  const DexaCreator = await ethers.getContractFactory("DexaCreator");
  console.log("Deploying DexaCreator...");
  const dexaCreator = await upgrades.deployProxy(DexaCreator, [owner.address], {
    initializer: "init_dexa_creator",
    initialOwner: owner.address,
  });
  await dexaCreator.waitForDeployment();
  const dexaCreatorAddr = await dexaCreator.getAddress();
  console.log("DexaCreator deployed to:", dexaCreatorAddr);

  const DexaFeeds = await ethers.getContractFactory("DexaFeeds");
  console.log("Deploying DexaFeeds...");
  const dexaFeeds = await upgrades.deployProxy(
    DexaFeeds,
    [dexaCreatorAddr, owner.address, feedsTokenAddr],
    {
      initializer: "init_dexa_feed",
      initialOwner: owner.address,
    }
  );
  await dexaFeeds.waitForDeployment();
  const dexaFeedsAddr = await dexaFeeds.getAddress();
  console.log("DexaFeeds deployed to:", dexaFeedsAddr);
  await dexaFeeds.addTokenToWhitelist([
    "0x337610d27c682e347c9cd60bd4b3b107c9d34ddd",
    "0x2fC661046c3365ecb408a491F14828eA90587304",
    "0x84b9B910527Ad5C03A9Ca831909E21e236EA7b06",
  ]);

  // const DexaStorage = await ethers.getContractFactory("DexaStorage");
  // console.log("Deploying DexaStorage...");
  // const dexaStorage = await upgrades.deployProxy(
  //   DexaStorage,
  //   [
  //     dexaCreatorAddr,
  //     owner.address,
  //     "0xF0Bcf6E4F72bCB33b944275dd5c9d4540a259eB9",
  //     "0xCAB5728B7cc21D0056E237D371b28efEEBFd8C2d",
  //     "0xb23002c5C3DCe3312e190d9D186C4aB29F7cF26F",
  //     "0xe53725ac14bD77fA4754fC5a09889135C2c7Bc25",
  //     10000000,
  //     0,
  //   ],
  //   {
  //     initializer: "init_dexa_storage",
  //     initialOwner: owner.address,
  //   }
  // );
  // await dexaStorage.waitForDeployment();
  // const dexaStorageAddr = await dexaStorage.getAddress();
  // console.log("DexaStorage deployed to:", dexaStorageAddr);

  await feedsToken.init_roles(dexaCreatorAddr, dexaFeedsAddr);
  await dexaCreator.init_roles(dexaFeedsAddr);
  await dexaFeeds.init_roles(dexaCreatorAddr);
}

// We recommend this pattern to be able to use async/await everywhere
// and properly handle errors.
main().catch((error) => {
  console.error(error);
  process.exitCode = 1;
});
