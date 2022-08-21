const hre = require("hardhat");

const overrides = {
    gasLimit: 9999999
}

const MaxUint256 = '0xffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffff';

async function main() {
  accounts = await hre.ethers.getSigners();

  let erc20 = '0x0'

  const tokenLockFactory = await hre.ethers.getContractFactory("TokenLock");
  const tokenLockContract = await tokenLockFactory.deploy(accounts[0].address, erc20, overrides);
  tokenLockContract.deployed();

  console.log("tokenLockContract deployed to:", tokenLockContract.address);

  // if( allowance == 0 ){
  //     tx = await TokenContract.approve(tokenLockContract.address, MaxUint256);
  //     tx.wait();
  // } 
}


main()
  .then(() => process.exit(0))
  .catch((error) => {
    console.error(error);
    process.exit(1);
  });
