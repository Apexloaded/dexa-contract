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
    feedsToken = await FeedsToken.attach(
      "0x32bF594b5002eEF18C164F4340756CF68A697aa3"
    );

    const DexaCreator = await ethers.getContractFactory("DexaCreator");
    dexaCreator = await DexaCreator.attach(
      "0xa11FC023Ed3a655DE0e56BE9e68fd6c18dC5F70E"
    );

    const DexaFeeds = await ethers.getContractFactory("DexaFeeds");
    dexaFeeds = await DexaFeeds.attach(
      "0xb12A9cA9CC4Fa2ed2Ec45d00b23cA9CDBf23bC54"
    );
  });

  describe("Dexa Social", () => {
    it("Should add a creator", async () => {
      await expect(
        dexaCreator.registerCreator(
          "James Harden",
          "jamesharden",
          "profile",
          "bio"
        )
      ).to.rejectedWith("Dexa: 2");
    });

    it("Should mint a post", async () => {
      const tx = await dexaFeeds.mintPost(
        "cb60d7b9-0cf5-4833-b090-77813b94a06b",
        "https://gnfd-testnet-sp1.bnbchain.org/view/dexa/feeds/cb60d7b9-0cf5-4833-b090-77813b94a06b/post",
        "100000000000000000",
        "0x337610d27c682e347c9cd60bd4b3b107c9d34ddd",
        "https://gnfd-testnet-sp1.bnbchain.org/view/dexa/feeds/cb60d7b9-0cf5-4833-b090-77813b94a06b/metadata"
      );
      tx.wait(3)
      const mintedPost = await dexaFeeds.postBygnfdId(
        "cb60d7b9-0cf5-4833-b090-77813b94a06b"
      );
      expect(mintedPost[0]).to.equal("cb60d7b9-0cf5-4833-b090-77813b94a06b");
    });
  });
});
