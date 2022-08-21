const { expect, assert } = require("chai");
const { ethers, waffle } = require("hardhat");
const { Bignumber } = require("ethers");




describe("tokenLock", function () {

    let accounts;
    let ERC20Contract;
    let tokenLockContract;
    const MaxUint256 = '0xffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffff';

    let MONTHS = 2592000;

    const overrides = {
        gasLimit: 9999999
    }


    beforeEach(async function () { 
        accounts = await ethers.getSigners();
        ERC20Contract = await (await ethers.getContractFactory("MockToken")).deploy();
        tokenLockContract = await (await ethers.getContractFactory("TokenLock")).deploy(accounts[0].address, ERC20Contract.address);

        allowance = await ERC20Contract.allowance(accounts[0].address, tokenLockContract.address);
        if( allowance == 0 ){
            tx = await ERC20Contract.approve(tokenLockContract.address, MaxUint256);
            tx.wait();
        }    

        let lockupInfo = [
            [accounts[0].address, ethers.utils.parseEther("0.1"), 1],
            [accounts[0].address, ethers.utils.parseEther("0.1"), MONTHS*2],
            [accounts[0].address, ethers.utils.parseEther("0.1"), MONTHS*3]
        ]

        
        const abiCoder = ethers.utils.defaultAbiCoder;
        const encodeLockupInfo = abiCoder.encode(["tuple(address, uint256, uint256)[]"], [lockupInfo]);

        tx = await tokenLockContract.setLockups(encodeLockupInfo, overrides);
        tx.wait();
    });


     it("setLockups, 동시에 많은 Lockup", async function() {  

        let lockupInfo = [
            [accounts[1].address, ethers.utils.parseEther("0.1"), MONTHS*1],
            [accounts[1].address, ethers.utils.parseEther("0.1"), MONTHS*2],
            [accounts[1].address, ethers.utils.parseEther("0.1"), MONTHS*3],
            [accounts[1].address, ethers.utils.parseEther("0.1"), MONTHS*4],
            [accounts[1].address, ethers.utils.parseEther("0.1"), MONTHS*5],
            [accounts[1].address, ethers.utils.parseEther("0.1"), MONTHS*6],
            [accounts[1].address, ethers.utils.parseEther("0.1"), MONTHS*7],
            [accounts[1].address, ethers.utils.parseEther("0.1"), MONTHS*8],
            [accounts[1].address, ethers.utils.parseEther("0.1"), MONTHS*9],
            [accounts[1].address, ethers.utils.parseEther("0.1"), MONTHS*10],
        ]
        
        const abiCoder = ethers.utils.defaultAbiCoder;
        const encodeLockupInfo = abiCoder.encode(["tuple(address, uint256, uint256)[]"], [lockupInfo]);

        tx = await tokenLockContract.setLockups(encodeLockupInfo, overrides);
        tx.wait();

        lockupInfo = await tokenLockContract.getLockupsAdmin();
        assert.equal( lockupInfo.length, 13);
    });

    it("setLockup, 단일 Lockup", async function() {  
        tx = await tokenLockContract.setLockup(accounts[1].address, ethers.utils.parseEther("0.1"), MONTHS, overrides);
        tx.wait();

        lockupInfo = await tokenLockContract.getLockupAdmin(3);
        assert.equal( lockupInfo.index, 3);
    });


    it("getLockupsAdmin, 전체 Lockup 된 상태 확인", async function() {  
        lockupInfo = await tokenLockContract.getLockupsAdmin();
        assert.equal( lockupInfo.length, 3);
    });

    it("getLockupAdmin, 특정 Lockup 상태 확인", async function() {  
        lockupInfo = await tokenLockContract.getLockupAdmin(1);
        assert.equal(lockupInfo.index, 1)
    });

    it("getBalanceAdmin, 특정 Lockup 수령 가능 여부 확인", async function() { 
        //임의 트랜잭션발생
        await ERC20Contract.approve(tokenLockContract.address, MaxUint256);

        balance = await tokenLockContract.getBalanceAdmin(0);
        assert.equal(balance, 100000000000000000n);
        
        balance = await tokenLockContract.getBalanceAdmin(1);
        assert.equal(balance, 0);
    });
  
    it("removeLockup, 특정 Lockup 제거", async function() {  
        tx = await tokenLockContract.removeLockup(accounts[0].address, 1);
        tx.wait();

        lockupInfo = await tokenLockContract.getLockupAdmin(1);
        assert.equal( lockupInfo.amount, 0);
    });


    it("withdraws, 전체 Lockup 찾기", async function() {  
        beforeBalance = await ERC20Contract.balanceOf(accounts[0].address);

        tx = await tokenLockContract.withdraws();
        tx.wait();

        afterBalance = await ERC20Contract.balanceOf(accounts[0].address);

        assert.equal( ethers.BigNumber.from(afterBalance).sub(beforeBalance), 100000000000000000n )
    });


    it("withdraw, 하나 Lockup 찾기", async function() {  
        beforeBalance = await ERC20Contract.balanceOf(accounts[0].address);

        tx = await tokenLockContract.withdraw(0);
        tx.wait();

        afterBalance = await ERC20Contract.balanceOf(accounts[0].address);

        assert.equal( ethers.BigNumber.from(afterBalance).sub(beforeBalance), 100000000000000000n )
    });

    
    it("getLockups, 소유중인 Lockup 정보 얻기", async function() {  
        lockupInfo = await tokenLockContract.getLockups();
        assert.equal( lockupInfo.length, 3 )
    });
});
