const { expect, assert } = require("chai");
const { ethers, waffle } = require("hardhat");
const { Bignumber } = require("ethers");

const helpers = require("@nomicfoundation/hardhat-network-helpers");



describe("TokenLock", function () {

    let accounts;
    let TokenContract;
    let LockupContract;
    const MaxUint256 = '0xffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffff';

    let MONTHS = 2592000;

    let ONE_MONTH = 2592000;

    const overrides = {
        gasLimit: 9999999
    }


    beforeEach(async function () { 
        accounts = await ethers.getSigners();
        TokenContract = await (await ethers.getContractFactory("MockToken")).deploy();
        LockupContract = await (await ethers.getContractFactory("TokenLock")).deploy([accounts[0].address, accounts[1].address, accounts[2].address], TokenContract.address);

        allowance = await TokenContract.allowance(accounts[0].address, LockupContract.address);
        if( allowance == 0 ){
            tx = await TokenContract.approve(LockupContract.address, MaxUint256);
            tx.wait();
        }    


        let lockupInfo = [
            [accounts[0].address, ethers.utils.parseEther("0.1"), Math.floor(Date.parse('9/1/2022, 15:38:00')/1000)],
            [accounts[0].address, ethers.utils.parseEther("0.1"), Math.floor(Date.parse('9/1/2023, 15:39:00')/1000)],
            [accounts[0].address, ethers.utils.parseEther("0.1"), Math.floor(Date.parse('9/1/2023, 15:45:00')/1000)],
            [accounts[1].address, ethers.utils.parseEther("0.1"), Math.floor(Date.parse('9/1/2022, 15:38:00')/1000)],
            [accounts[1].address, ethers.utils.parseEther("0.1"), Math.floor(Date.parse('9/1/2023, 15:39:00')/1000)],
            [accounts[1].address, ethers.utils.parseEther("0.1"), Math.floor(Date.parse('9/1/2022, 15:45:00')/1000)]
        ]

        
        const abiCoder = ethers.utils.defaultAbiCoder;
        const encodeLockupInfo = abiCoder.encode(["tuple(address, uint256, uint256)[]"], [lockupInfo]);

        tx = await LockupContract.setLockups(encodeLockupInfo, overrides);
        tx.wait();

    });

     it("setLockups, 동시에 많은 Lockup", async function() {  
    
        let lockupInfo = [
            [accounts[1].address, ethers.utils.parseEther("0.1"),  Math.floor(Date.parse('9/1/2022, 15:38:00')/1000)],
            [accounts[1].address, ethers.utils.parseEther("0.1"),  Math.floor(Date.parse('9/1/2022, 15:39:00')/1000)],
            [accounts[1].address, ethers.utils.parseEther("0.1"),  Math.floor(Date.parse('9/1/2022, 15:40:00')/1000)],
            [accounts[1].address, ethers.utils.parseEther("0.1"),  Math.floor(Date.parse('9/1/2022, 15:41:00')/1000)],
            [accounts[1].address, ethers.utils.parseEther("0.1"),  Math.floor(Date.parse('9/1/2022, 15:42:00')/1000)],
            [accounts[1].address, ethers.utils.parseEther("0.1"),  Math.floor(Date.parse('9/1/2022, 15:43:00')/1000)],
            [accounts[1].address, ethers.utils.parseEther("0.1"),  Math.floor(Date.parse('9/1/2022, 15:44:00')/1000)],
            [accounts[1].address, ethers.utils.parseEther("0.1"),  Math.floor(Date.parse('9/1/2022, 15:45:00')/1000)],
            [accounts[1].address, ethers.utils.parseEther("0.1"),  Math.floor(Date.parse('9/1/2022, 15:46:00')/1000)],
            [accounts[1].address, ethers.utils.parseEther("0.1"),  Math.floor(Date.parse('9/1/2022, 15:47:00')/1000)],
        ]

        
        const abiCoder = ethers.utils.defaultAbiCoder;
        const encodeLockupInfo = abiCoder.encode(["tuple(address, uint256, uint256)[]"], [lockupInfo]);

        tx = await LockupContract.setLockups(encodeLockupInfo, overrides);
        tx.wait();

        lockupInfo = await LockupContract.getLockupsAdmin();
        assert.equal( lockupInfo.length, 16);
    }).timeout(1000*60)

    it("setLockup, 단일 Lockup", async function() {  
        tx = await LockupContract.setLockup(accounts[1].address, ethers.utils.parseEther("0.1"), Math.floor(Date.parse('9/1/2023, 15:38:00')/1000), overrides);
        tx.wait();

        lockupInfo = await LockupContract.getLockupAdmin(3);
        assert.equal( lockupInfo.index, 3);
    });


    it("getLockupsAdmin, 전체 Lockup 된 상태 확인", async function() {  
        lockupInfo = await LockupContract.getLockupsAdmin();
        assert.equal( lockupInfo.length, 6);
    });
    
    it("getLockupsAccountAdmin, 특정 Lockup 계정 상태 확인", async function() {  
        lockupInfo = await LockupContract.getLockupsAccountAdmin(accounts[1].address);
        assert.equal( lockupInfo.length, 3);
    });

    it("getLockupAdmin, 특정 Lockup 상태 확인", async function() {  
        lockupInfo = await LockupContract.getLockupAdmin(1);
        assert.equal(lockupInfo.index, 1)
    });


    it("getBalanceAdmin, 특정 Lockup 수령 가능 여부 확인", async function() { 
        //임의 트랜잭션발생
        await TokenContract.approve(LockupContract.address, MaxUint256);

        balance = await LockupContract.getBalanceAdmin(0);
        assert.equal(balance, 100000000000000000n);
        
        balance = await LockupContract.getBalanceAdmin(1);
        assert.equal(balance, 0);
    });
  
    it("removeLockups, Lockup들 제거", async function() {         

        let lockupInfo = [
            [accounts[0].address, 0],
            [accounts[0].address, 1]
        ]
        
        const abiCoder = ethers.utils.defaultAbiCoder;
        const encodeLockupInfo = abiCoder.encode(["tuple(address, uint256)[]"], [lockupInfo]);

        await LockupContract.estimateGas.removeLockups(encodeLockupInfo, accounts[0].address, overrides);
    });


    it("withdraws, 전체 Lockup 찾기", async function() {  
        beforeBalance = await TokenContract.balanceOf(accounts[0].address);

        tx = await LockupContract.withdraws();
        tx.wait();

        afterBalance = await TokenContract.balanceOf(accounts[0].address);

        assert.equal( ethers.BigNumber.from(afterBalance).sub(beforeBalance), 100000000000000000n )
    });


    it("withdraw, 하나 Lockup 찾기", async function() {  
        beforeBalance = await TokenContract.balanceOf(accounts[0].address);

        tx = await LockupContract.withdraw(0);
        tx.wait();

        afterBalance = await TokenContract.balanceOf(accounts[0].address);

        assert.equal( ethers.BigNumber.from(afterBalance).sub(beforeBalance), 100000000000000000n )
    });

    
    it("getLockups, 소유중인 Lockup 정보 얻기", async function() {  
        lockupInfo = await LockupContract.getLockups();
        assert.equal( lockupInfo.length, 3 )
    });

    

});
