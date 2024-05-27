import { ethers, upgrades, network } from "hardhat";

async function main() {
  const [owner] = await ethers.getSigners();
  const dexaCreatorAddr = "0xb1978d2c929C808dFA7b3B79730B761446458581";
  const DexaMessenger = await ethers.getContractFactory("DexaMessenger");
  console.log("Deploying DexaMessenger...");
  const dexaMessenger = await upgrades.deployProxy(
    DexaMessenger,
    [dexaCreatorAddr, owner.address],
    {
      initializer: "init_dexa_messenger",
      initialOwner: owner.address,
    }
  );
  await dexaMessenger.waitForDeployment();
  const dexaMessengerAddr = await dexaMessenger.getAddress();
  console.log("dexaMessenger deployed to:", dexaMessengerAddr);

  await dexaMessenger.init_roles(dexaCreatorAddr);
}

main().catch((error) => {
  console.error(error);
  process.exitCode = 1;
});