const { network } = require("hardhat");
const { verify } = require("../utils/verify");

module.exports = async ({ deployments, getNamedAccounts }) => {
  const { deploy, log } = deployments;
  const { deployer } = await getNamedAccounts();
  const chainId = network.config.chainId;

  console.log("----Deploying Contract----");
  const arguments = [];
  const NFTmarketPlace = await deploy("NftMarketplace", {
    from: deployer,
    args: arguments,
    log: true,
  });
  console.log("----Contract Deployed----");

  if (chainId != 31337 && process.env.ETHERSCAN_APIKEY) {
    await verify(NFTmarketPlace.address, arguments);
  }
};

module.exports.tags = ["all", "market"];
