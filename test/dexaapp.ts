import { expect } from "chai";
import hre, { ethers, upgrades } from "hardhat";
import { SignerWithAddress } from "@nomicfoundation/hardhat-ethers/signers";
import { client, selectSp } from "../client";

describe("Dexa", () => {
  let owner: SignerWithAddress;
  let otherAccount: SignerWithAddress;
  let dexaCreator: any;
  let dexaFeeds: any;
  let feedsToken: any;
  let dexaStorage: any;
  let dexaStorageAddr: string;

  before(async function () {
    [owner, otherAccount] = await ethers.getSigners();
    const FeedsToken = await ethers.getContractFactory("FeedsToken");
    console.log("Deploying FeedsToken...");
    feedsToken = await upgrades.deployProxy(FeedsToken, [owner.address], {
      initializer: "init_feed_token",
      initialOwner: owner.address,
    });
    await feedsToken.waitForDeployment();
    const feedsTokenAddr = await feedsToken.getAddress();
    console.log("FeedsToken deployed to:", feedsTokenAddr);

    const DexaCreator = await ethers.getContractFactory("DexaCreator");
    console.log("Deploying DexaCreator...");
    dexaCreator = await upgrades.deployProxy(DexaCreator, [owner.address], {
      initializer: "init_dexa_creator",
      initialOwner: owner.address,
    });
    await dexaCreator.waitForDeployment();
    const dexaCreatorAddr = await dexaCreator.getAddress();
    console.log("DexaCreator deployed to:", dexaCreatorAddr);

    const DexaFeeds = await ethers.getContractFactory("DexaFeeds");
    console.log("Deploying DexaFeeds...");
    dexaFeeds = await upgrades.deployProxy(
      DexaFeeds,
      [dexaCreatorAddr, owner.address],
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
    ]);

    await feedsToken.init_roles(dexaCreatorAddr, dexaFeedsAddr);
    await dexaCreator.init_roles(dexaFeedsAddr);
    await dexaFeeds.init_roles(dexaCreatorAddr);
  });

  describe("Dexa Social", () => {
    it("Should add a creator", async () => {
      console.log(owner.address);
      const tx = await dexaCreator.registerCreator(
        "James Harden",
        "jamesharden",
        "profile",
        "bio"
      );
      tx.wait(3);
      const creator = await dexaCreator.getCreator(owner.address);
      expect(creator[2]).to.equal(owner.address);
    });

    it("Should mint a post", async () => {
      const tx = await dexaFeeds.mintPost(
        "cb60d7b9-0cf5-4833-b090-77813b94a06b",
        "https://gnfd-testnet-sp1.bnbchain.org/view/dexa/feeds/cb60d7b9-0cf5-4833-b090-77813b94a06b/post",
        "100000000000000000",
        "0x337610d27c682e347c9cd60bd4b3b107c9d34ddd",
        "https://gnfd-testnet-sp1.bnbchain.org/view/dexa/feeds/cb60d7b9-0cf5-4833-b090-77813b94a06b/metadata"
      );
      tx.wait(3);
      const mintedPost = await dexaFeeds.postBygnfdId(
        "cb60d7b9-0cf5-4833-b090-77813b94a06b"
      );
      expect(mintedPost[0]).to.equal("cb60d7b9-0cf5-4833-b090-77813b94a06b");
    });
  });
});
