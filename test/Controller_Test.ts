import { expect } from "chai";
import { ethers } from "hardhat";

describe("Deploy Controller", function () {
  async function deployContract() {
    const [owner, test, rewards, gov] = await ethers.getSigners();
    const TokenContract = await ethers.getContractFactory("Token");
    const token = await TokenContract.deploy();
    await token.deployed();
    const controllerContractFactory = await ethers.getContractFactory(
      "Controller"
    );
    const controller = await controllerContractFactory
      .connect(gov)
      .deploy(rewards.address);
    await controller.deployed();
    return { owner, test, rewards, controller, gov, token };
  }

  describe("Test Controller", function () {
    it("gov", async () => {
      const { gov, controller } = await deployContract();
      expect(await controller.governance()).to.equal(gov.address);
    });
    it("rewards", async () => {
      const { rewards, controller } = await deployContract();
      expect(await controller.rewards()).to.equal(rewards.address);
    });
    it("onesplit", async () => {
      const { controller } = await deployContract();
      expect(await controller.onesplit()).to.equal(
        "0x50FDA034C0Ce7a8f7EFDAebDA7Aa7cA21CC1267e"
      );
    });
    it("split", async () => {
      const { controller } = await deployContract();
      expect(await controller.split()).to.equal(500);
    });
  });
});
