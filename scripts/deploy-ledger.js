const hre = require("hardhat");
const { LedgerSigner } = require("@anders-t/ethers-ledger");

const overrides = {
    gasPrice: 50000000000,
    gasLimit: 9999999
}

const MaxUint256 = '0xffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffff';

async function main() {
    let ledger = new LedgerSigner(hre.ethers.provider);

    let ledgerAddress = await ledger.getAddress();
    console.log(ledgerAddress)

    let erc20 = '0x0'

    const tokenLockFactory = await hre.ethers.getContractFactory("TokenLock");
    const tokenLockContract = await tokenLockFactory.connect(ledger).deploy(ledgerAddress, erc20, overrides);
    tokenLockContract.deployed();

    console.log("tokenLockContract deployed to:", tokenLockContract.address);

    // allowance = await TokenContract.allowance(ledgerAddress, tokenLockContract.address);
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
