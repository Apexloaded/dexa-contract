import { expect } from "chai";
import { ethers, upgrades } from "hardhat";
import { SignerWithAddress } from "@nomicfoundation/hardhat-ethers/signers";

describe("Dexa", () => {
  let owner: SignerWithAddress;
  let otherAccount: SignerWithAddress;
  let dexaSocial: any;
  let dexaFeed: any;

  before(async function () {
    [owner, otherAccount] = await ethers.getSigners();
  });

  beforeEach(async function () {
    const DexaSocial = await ethers.getContractFactory("Dexa");
    dexaSocial = await upgrades.deployProxy(
      DexaSocial,
      [owner.address, 30 * 10],
      {
        initializer: "initialize",
        initialOwner: owner.address,
      }
    );
    await dexaSocial.waitForDeployment();
    console.log("DexaSocial deployed to:", await dexaSocial.getAddress());
  });

  describe("Dexa Social", () => {
    it("Should add a creator", async () => {
      const tx = await dexaSocial.registerCreator(
        "James Harden",
        "jamesharden",
        "profile",
        "bio"
      );
      tx.wait(3);
      const creator = await dexaSocial.getCreator(owner.address);
      expect(creator[2]).to.equal(owner.address);
    });

    it("Should add a Post", async () => {
      const regTx = await dexaSocial.registerCreator(
        "James Harden",
        "jamesharden",
        "profile",
        "bio"
      );
      regTx.wait(3);

      const createTx = await dexaSocial.mintPost("James Harden", 3, "");
      createTx.wait(3);
      const post = await dexaSocial.getPost(0);
      expect(post[0]).to.equal(0);
    });

    it("Should get all posts", async () => {
      const regTx = await dexaSocial.registerCreator(
        "James Harden",
        "jamesharden",
        "profile",
        "bio"
      );
      regTx.wait(3);

      const createTx1 = await dexaSocial.mintPost("Post 1", 3, "");
      createTx1.wait(3);
      const createTx2 = await dexaSocial.mintPost("Post 2", 3, "");
      createTx2.wait(3);
      const createTx3 = await dexaSocial.mintPost("Post 3", 3, "");
      createTx3.wait(3);

      const posts = await dexaSocial.listAllPosts();
      console.log(posts);
      expect(posts.length).to.equal(3);
    });

    it("Should get one post", async () => {
      const regTx = await dexaSocial.registerCreator(
        "James Harden",
        "jamesharden",
        "profile",
        "bio"
      );
      regTx.wait(3);

      const createTx1 = await dexaSocial.mintPost("Post 1", 3, "");
      createTx1.wait(3);
      const createTx2 = await dexaSocial.mintPost("Post 2", 3, "");
      createTx2.wait(3);
      const createTx3 = await dexaSocial.mintPost("Post 3", 3, "");
      createTx3.wait(3);

      const post = await dexaSocial.getPost(2);
      console.log(post);
      expect(post[1]).to.equal(owner.address);
    });

    it("Get all user posts", async () => {
      const regTx = await dexaSocial.registerCreator(
        "James Harden",
        "jamesharden",
        "profile",
        "bio"
      );
      regTx.wait(3);

      const createTx1 = await dexaSocial.mintPost("Post 1", 3, "");
      createTx1.wait(3);
      const createTx2 = await dexaSocial.mintPost("Post 2", 3, "");
      createTx2.wait(3);
      const createTx3 = await dexaSocial.mintPost("Post 3", 3, "");
      createTx3.wait(3);

      await dexaSocial
        .connect(otherAccount)
        .registerCreator("Ether User", "ethers", "profile", "bio");
      regTx.wait(3);

      const secondUserTx1 = await dexaSocial
        .connect(otherAccount)
        .mintPost("Post 1", 3, "");
      secondUserTx1.wait(3);
      const secondUserTx2 = await dexaSocial
        .connect(otherAccount)
        .mintPost("Post 2", 3, "");
      secondUserTx2.wait(3);
      const secondUserTx3 = await dexaSocial
        .connect(otherAccount)
        .mintPost("Post 3", 3, "");
      secondUserTx3.wait(3);

      const posts = await dexaSocial.listAllPosts();
      expect(posts.length).to.equal(6);
    });

    it("Get only user post", async () => {
      const regTx = await dexaSocial.registerCreator(
        "James Harden",
        "jamesharden",
        "profile",
        "bio"
      );
      regTx.wait(3);

      const createTx1 = await dexaSocial.mintPost("Post 1", 3, "");
      createTx1.wait(3);
      const createTx2 = await dexaSocial.mintPost("Post 2", 3, "");
      createTx2.wait(3);
      const createTx3 = await dexaSocial.mintPost("Post 3", 3, "");
      createTx3.wait(3);

      await dexaSocial
        .connect(otherAccount)
        .registerCreator("Ether User", "ethers", "profile", "bio");
      regTx.wait(3);

      const secondUserTx1 = await dexaSocial
        .connect(otherAccount)
        .mintPost("Post 1", 3, "");
      secondUserTx1.wait(3);
      const secondUserTx2 = await dexaSocial
        .connect(otherAccount)
        .mintPost("Post 2", 3, "");
      secondUserTx2.wait(3);
      const secondUserTx3 = await dexaSocial
        .connect(otherAccount)
        .mintPost("Post 3", 3, "");
      secondUserTx3.wait(3);

      const posts = await dexaSocial.postByCreator(otherAccount);
      expect(posts.length).to.equal(3);
    });

    it("Get one creator", async () => {
      const regTx = await dexaSocial.registerCreator(
        "James Harden",
        "jamesharden",
        "profile",
        "bio"
      );
      regTx.wait(3);

      await dexaSocial
        .connect(otherAccount)
        .registerCreator("Ether User", "ethers", "profile", "bio");
      regTx.wait(3);

      const creator = await dexaSocial.getCreator(otherAccount);
      expect(creator[2]).to.equal(otherAccount);
    });

    it("Tip a posts", async () => {
      const regTx = await dexaSocial.registerCreator(
        "James Harden",
        "jamesharden",
        "profile",
        "bio"
      );
      regTx.wait(3);

      const createTx1 = await dexaSocial.mintPost("Post 1", 3, "");
      createTx1.wait(3);

      await dexaSocial
        .connect(otherAccount)
        .registerCreator("Ether User", "ethers", "profile", "bio");
      regTx.wait(3);

      const secondUserTx1 = await dexaSocial
        .connect(otherAccount)
        .mintPost("Post 1", 3, "");
      secondUserTx1.wait(3);

      const tipTx = await dexaSocial.tipPost(1, "Thank you for post", {
        value: ethers.parseEther("0.25"),
      });
      tipTx.wait(3);

      const creator = await dexaSocial.getCreator(otherAccount);
      console.log(creator);
      expect(creator[5]).to.equal(ethers.parseEther("0.25"));
    });
  });
});
