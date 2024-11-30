require("@nomicfoundation/hardhat-toolbox");
require("dotenv").config(); // Load .env variables

/** @type import('hardhat/config').HardhatUserConfig */
module.exports = {
  solidity: "0.8.20",

  networks: {
    sepolia: {
      url: process.env.INFURA_URL, 
      accounts: [process.env.PRIVATE_KEY],
      timeout: 200000,
    },
  },
};
