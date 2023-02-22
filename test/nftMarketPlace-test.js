const { expect, assert } = require("chai");
const { getNamedAccounts, deployments, ethers } = require("hardhat");

describe("NFTMarketPlace", () => {
  let deployer,
    NftMarketplaceContract,
    ourNFTContract,
    ourNFT,
    NFTmarketplace,
    user;
  const TOKEN_ID = 0;
  beforeEach(async () => {
    const accounts = await ethers.getSigners();
    deployer = accounts[0];
    user = accounts[1];
    await deployments.fixture(["all"]);
    NftMarketplaceContract = await ethers.getContract("NftMarketplace");
    ourNFTContract = await ethers.getContract("BasicNft");
    NFTmarketplace = NftMarketplaceContract.connect(deployer);
    ourNFT = ourNFTContract.connect(deployer);
    ourNFT._mint();
    ourNFT.approve(NFTmarketplace.address, TOKEN_ID);
  });
  const oneEth = ethers.utils.parseEther("1");
  describe("list Item", () => {
    it("should listItem and emit an event", async () => {
      const tx = NFTmarketplace.listItem(ourNFT.address, TOKEN_ID, oneEth);
      await expect(tx).to.emit(NftMarketplaceContract, "ItemListed");
    });
  });

  describe("buyItem", () => {
    it("Should successfully buy and the item should be out of the market", async () => {
      const listTx = await NFTmarketplace.listItem(
        ourNFT.address,
        TOKEN_ID,
        oneEth
      );
      await listTx.wait(1);
      const connectedMarketPlace = await NFTmarketplace.connect(user);
      const tx = await connectedMarketPlace.buyItem(ourNFT.address, TOKEN_ID, {
        value: oneEth,
      });
      await tx.wait(1);
      expect(tx).to.emit(NftMarketplaceContract, "itemBought");

      const sellerProceeds = await NFTmarketplace.getProceeds(deployer.address);
      assert(sellerProceeds > 0);
    });
  });
});
