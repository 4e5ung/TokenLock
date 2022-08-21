require('dotenv').config();
require("@nomiclabs/hardhat-waffle");
require('hardhat-abi-exporter');



// This is a sample Hardhat task. To learn how to create your own go to
// https://hardhat.org/guides/create-task.html
task("accounts", "Prints the list of accounts", async (taskArgs, hre) => {
  const accounts = await hre.ethers.getSigners();

  for (const account of accounts) {
    console.log(account.address);
  }
});

// You need to export an object to set up your config
// Go to https://hardhat.org/config/ to learn more

/**
 * @type import('hardhat/config').HardhatUserConfig
 */
module.exports = {
  defaultNetwork: "hardhat",
  networks: {
    hardhat: {
    },
    mumbai: {
      url: "https://matic-mumbai.chainstacklabs.com",
      chainId: 80001,
      // url: "https://rpc-mainnet.maticvigil.com/",
      accounts: [process.env.PRIVATE_KEY],
    },
    mumbai_ledger: {
      url: "https://matic-mumbai.chainstacklabs.com",
      chainId: 80001,
    },
    polygon: {
      url: "https://rpc-mainnet.maticvigil.com",
      chainId: 137,
      accounts: [process.env.PRIVATE_KEY],
    },
    polygon_ledger: {
      url: "https://polygon-mainnet.infura.io/v3/90c47f0cffda4ff3a710fe5e7e8d00fe",
      chainId: 137,
    },
   },
  solidity: {    
    compilers: [
      {
        version: "0.8.13",
        settings: {},
      },
    ], 
  },
  mocha: {
    timeout: 300000
  },
  // abiExporter: {
  //   path: './abi',
  //   clear: true,
  //   flat: true,
  //   except: ['openzeppelin', './token', "./interfaces", "./access", "./utils"]
  // },
};
