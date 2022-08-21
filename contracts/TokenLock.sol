// SPDX-License-Identifier: MIT
pragma solidity ^0.8.13;

import "./interfaces/IERC20.sol";

contract TokenLock{
    address private admin;
    address private token;

    uint256 private lockupIndex = 0;
    uint256 private totalAmount = 0;
    uint256 private lockupCount = 0;

    mapping( address => uint256[] ) private accountToLockupIndex;
    mapping( uint256 => LockupInfo ) private lockupInfo;

    struct LockupInfo{
        address account;
        uint256 timestamp;
        uint256 amount;
        uint256 duration;
        uint256 index;
    }

    struct LockupResultInfo{
        uint256 timestamp;
        uint256 amount;
        uint256 duration;
        uint256 index;
    }

    struct Lockups{
        address account;
        uint256 amount;
        uint256 duration;
    }

    event setLockupEvent(address, uint256, uint256);
    event setLockupsEvent(address, uint256, uint256);
    event withdrawEvent(address, uint256, uint256);
    event withdrawsEvent(address, uint256);

    constructor(address _admin, address _token) {
        admin = _admin;
        token = _token;

        IERC20(token).approve(address(this), type(uint256).max);
	}

    modifier onlyAdmin(){
         require(admin == msg.sender, "TokenLock: E01");
        _;
    }

    modifier onlyLock(uint _lockupIndex){
        require(isLockInfo(msg.sender), "TokenLock: E02");
        require(isLockIndex(msg.sender, _lockupIndex), "TokenLock: E03");

        _;
    }

    function setLockups(bytes memory _lockups) external onlyAdmin(){
        (Lockups[] memory lockups ) = abi.decode(_lockups, (Lockups[]));

        for( uint256 i = 0; i < lockups.length; i++ ){
            IERC20(token).transferFrom(admin, address(this), lockups[i].amount);

            lockupInfo[lockupIndex] = LockupInfo({
            amount : lockups[i].amount,
            timestamp : block.timestamp,
            duration : lockups[i].duration,
            account :lockups[i].account,
            index : lockupIndex   
        });

        accountToLockupIndex[lockups[i].account].push(lockupIndex);

        totalAmount += lockups[i].amount;
        lockupIndex++;
        lockupCount++;

        emit setLockupsEvent(lockups[i].account, lockups[i].amount, lockups[i].duration);
        }
    }

    function setLockup(address _account, uint256 _amount, uint256 _duration) external onlyAdmin(){
        require( _account != address(0), "TokenLock: E04");
        require( _amount > 0, "TokenLock: E05");
        require( _duration > 0, "TokenLock: E06");

        IERC20(token).transferFrom(admin, address(this), _amount);
        
        lockupInfo[lockupIndex] = LockupInfo({
            amount : _amount,
            timestamp : block.timestamp,
            duration : _duration,
            account : _account,
            index : lockupIndex   
        });

        accountToLockupIndex[_account].push(lockupIndex);

        totalAmount += _amount;
        lockupIndex++;
        lockupCount++;

        emit setLockupEvent(_account, _amount, _duration);
    }

    function removeLockup(address _account, uint256 _lockupIndex) external onlyAdmin(){
        require(isLockInfo(_account), "TokenLock: E02");
        require(isLockIndex(_account, _lockupIndex), "TokenLock: E03");

        LockupInfo memory info = lockupInfo[_lockupIndex];

        IERC20(token).transferFrom(address(this), admin, info.amount);

        delete lockupInfo[_lockupIndex];

        uint256 index = 0;
        for( index; index < accountToLockupIndex[msg.sender].length; index++ ){
            if( accountToLockupIndex[msg.sender][index] == _lockupIndex )
                break;            
        }

        if( accountToLockupIndex[msg.sender].length > 0 ){
            accountToLockupIndex[msg.sender][index] = accountToLockupIndex[msg.sender][accountToLockupIndex[msg.sender].length-1];
            accountToLockupIndex[msg.sender].pop();
        } 

        totalAmount -= info.amount;       
        lockupCount--;
    }
    
    function isLockInfo(address _account) internal view returns(bool) {
        if( accountToLockupIndex[_account].length > 0 )
            return true;
        else
            return false;
    }

    function isLockIndex(address _account, uint256 _lockupIndex) internal view returns(bool) {
        if( lockupInfo[_lockupIndex].account == _account )
            return true;
        else
            return false;
    }

    function getLockupsAdmin() public view onlyAdmin returns(LockupInfo[] memory list){
        LockupInfo[] memory infoList = new LockupInfo[](lockupCount);

        uint256 k;
        for( uint256 i = 0; i < lockupIndex; i++ ){
            if( lockupInfo[i].amount != 0 ){
                infoList[k].amount = lockupInfo[i].amount;
                infoList[k].duration = lockupInfo[i].duration;
                infoList[k].timestamp = lockupInfo[i].timestamp;
                infoList[k].index = lockupInfo[i].index;
                infoList[k].account = lockupInfo[i].account;
                k++;
            }
        }

        return infoList;
    }

    function getLockupAdmin(uint256 _lockupIndex) public view onlyAdmin returns(LockupInfo memory info){
        if( lockupInfo[_lockupIndex].amount != 0 ){
            info.amount = lockupInfo[_lockupIndex].amount;
            info.duration = lockupInfo[_lockupIndex].duration;
            info.timestamp = lockupInfo[_lockupIndex].timestamp;
            info.index = lockupInfo[_lockupIndex].index;
            info.account = lockupInfo[_lockupIndex].account;
        }
    }

    function getBalanceAdmin(uint256 _lockupIndex) public view onlyAdmin returns(uint256 amount){
        uint256 curTime = block.timestamp;

        LockupInfo memory info = lockupInfo[_lockupIndex];

        if( info.timestamp+info.duration <= curTime )
            amount = info.amount;
        else
            amount = 0;
    }

    function getLockups() public view returns(LockupResultInfo[] memory list){
        require(isLockInfo(msg.sender), "TokenLock: E02");

        LockupResultInfo[] memory infoList = new LockupResultInfo[](accountToLockupIndex[msg.sender].length);

        for( uint256 i = 0; i < accountToLockupIndex[msg.sender].length; i++ ){
            infoList[i].amount = lockupInfo[accountToLockupIndex[msg.sender][i]].amount;
            infoList[i].duration = lockupInfo[accountToLockupIndex[msg.sender][i]].duration;
            infoList[i].timestamp = lockupInfo[accountToLockupIndex[msg.sender][i]].timestamp;
            infoList[i].index = accountToLockupIndex[msg.sender][i];
        }   

        return infoList;
    }

    function getBalance(uint256 _lockupIndex) public view onlyLock(_lockupIndex) returns(uint256 amount){
        uint256 curTime = block.timestamp;

        LockupInfo memory info = lockupInfo[_lockupIndex];

        if( info.timestamp+info.duration <= curTime )
            amount = info.amount;
        else
            amount = 0;
    }

    function withdraw(uint256 _lockupIndex) public onlyLock(_lockupIndex) returns(uint256 withdrawBalance){
        uint256 balance = getBalance(_lockupIndex);

        require(balance > 0, "TokenLock: E05");
        require(IERC20(token).transferFrom(address(this), msg.sender, balance));

        delete lockupInfo[_lockupIndex];

        uint256 index = 0;
        for( index; index < accountToLockupIndex[msg.sender].length; index++ ){
            if( accountToLockupIndex[msg.sender][index] == _lockupIndex ){
                break;            
            }
        }

        if( accountToLockupIndex[msg.sender].length > 0 ){
            accountToLockupIndex[msg.sender][index] = accountToLockupIndex[msg.sender][accountToLockupIndex[msg.sender].length-1];
            accountToLockupIndex[msg.sender].pop();
        } 

        totalAmount -= balance;
        lockupCount--;
        withdrawBalance = balance;

        emit withdrawEvent(msg.sender, _lockupIndex, balance);
    }

    function withdraws() public returns(uint256 withdrawsBalance){
        require(isLockInfo(msg.sender), "TokenLock: E02");

        uint256 curTime = block.timestamp;
        uint256 withdrawCount;
        uint256 balance;

        for( uint256 i = 0; i < accountToLockupIndex[msg.sender].length; i++ ){
            if( lockupInfo[accountToLockupIndex[msg.sender][i]].timestamp+lockupInfo[accountToLockupIndex[msg.sender][i]].duration <= curTime ){
                balance += lockupInfo[accountToLockupIndex[msg.sender][i]].amount;
                withdrawCount++;                
            }
        }

        require(balance > 0, "TokenLock: E05");
        require(IERC20(token).transferFrom(address(this), msg.sender, balance));

        for( uint256 k = 0; k < withdrawCount; k++ ){
             for( uint256 i = 0; i < accountToLockupIndex[msg.sender].length; i++ ){
                uint256 checkLockupIndex = accountToLockupIndex[msg.sender][i];                    
                if( lockupInfo[checkLockupIndex].timestamp+lockupInfo[checkLockupIndex].duration <= curTime ){                        
                    if( accountToLockupIndex[msg.sender].length > 0 ){
                        accountToLockupIndex[msg.sender][i] = accountToLockupIndex[msg.sender][accountToLockupIndex[msg.sender].length-1];
                        accountToLockupIndex[msg.sender].pop();
                    }

                    delete lockupInfo[checkLockupIndex];

                    break;
                }
             }
        }      

        totalAmount -= balance;
        lockupCount = lockupCount- withdrawCount;
        withdrawsBalance = balance;

        emit withdrawsEvent(msg.sender, balance);
    }
}