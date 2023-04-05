// SPDX-License-Identifier: MIT
pragma solidity ^0.8.13;

import './token/ERC20/IERC20.sol';
import './security/ReentrancyGuard.sol';

///@dev TokenLock lockup contract
contract TokenLock is ReentrancyGuard{
    uint8 private constant ADMINS_COUNT = 3;
    uint256 private constant EXPIRES = 1 hours;

    address private immutable token;
    address[ADMINS_COUNT] private admins;

    uint256 private lockupIndex = 0;
    uint256 private totalAmount = 0;
    uint256 private lockupCount = 0;

    mapping( address => uint256[] ) private accountToLockupIndex;
    mapping( uint256 => LockupInfo ) private lockupInfo;
    
    mapping (bytes4 => Confirm) public confirm;
        
    struct Confirm {
        uint256 expires;
        uint256 count;
        address[] accounts;
        bytes args;
    }

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

    struct LockupRemoveInfo{
        address account;
        uint256 index;
    }

    struct Lockups{
        address account;
        uint256 amount;
        uint256 endTime;
    }

    event ConfirmationComplete(address account, bytes4 method, uint256 confirmations);
    event ConfirmationRequired(address account, bytes4 method, uint256 confirmations, uint256 required);

    event setLockupEvent(address, uint256, uint256);
    event setLockupsEvent(address, uint256, uint256);
    event withdrawEvent(address, uint256, uint256);
    event withdrawsEvent(address, uint256);
    
    modifier onlyAdmin() {
        require(_isAdmin(msg.sender), "TokenLock: NOT_ADMIN");
        _;
    }

    modifier onlyLock(uint _lockupIndex){
        require(_isLockInfo(msg.sender), "TokenLock: NOT_LOCKINFO");
        require(_isLockIndex(msg.sender, _lockupIndex), "TokenLock: NOT_LOCKINDEX");
        _;
    }

    /// @dev Address setting constructor.
    /// @param _admins admins eoa
    /// @param _token erc20 address
    constructor(address[] memory _admins, address _token) {
        require(_admins.length == ADMINS_COUNT, "TokenLock: ADMIN_COUNT");
        
        for( uint256 i; i < _admins.length; i++ ){
            require(address(0) != _admins[i], "TokenLock: ZERO_ADDRESS");
        }

        require(address(0) != _token, "TokenLock: ZERO_ADDRESS");


        for( uint256 i; i < _admins.length; i++ ){
            admins[i] = _admins[i];
        }

        token = _token;

        IERC20(token).approve(address(this), type(uint256).max);
	}

    ///@dev check admin eoa
    ///@param _account eoa address
    function _isAdmin(address _account) internal view returns (bool) {
        for(uint i; i < admins.length; i++) {
            if(admins[i] ==_account) 
                return true;
        }

        return false;
    }

    ///@dev check lockinfo of eoa
    ///@param _account eoa address
    function _isLockInfo(address _account) internal view returns(bool) {
        if( accountToLockupIndex[_account].length > 0 )
            return true;
        else
            return false;
    }

    ///@dev check lockupindex of eoa
    ///@param _account eoa address
    ///@param _lockupIndex lockupindex
    function _isLockIndex(address _account, uint256 _lockupIndex) internal view returns(bool) {
        if( lockupInfo[_lockupIndex].account == _account )
            return true;
        else
            return false;
    }

    ///@dev confirm admin func
    ///@param _required number of managers required
    ///@param _method msg.sig
    ///@param _args msg.data
    function _confirmCall(uint256 _required, bytes4 _method, bytes calldata _args) internal onlyAdmin() returns(bool){
        if( confirm[_method].expires != 0 && ((confirm[_method].expires < block.timestamp) || (keccak256(confirm[_method].args) != keccak256(_args)))){
            delete confirm[_method];
        }

        for( uint i; i < confirm[_method].accounts.length; i++ ){
            if( confirm[_method].accounts[i] == msg.sender ){
                return false;
            }
        }

        confirm[_method].accounts.push(msg.sender);

        if( confirm[_method].accounts.length == _required ) {
            emit ConfirmationComplete(msg.sender, _method, _required);
            delete confirm[_method];
            return true;
        }

        if( confirm[_method].count == 0 ){
            confirm[_method].args = _args;
            confirm[_method].expires = block.timestamp + EXPIRES;
        }

        confirm[_method].count = confirm[_method].accounts.length;       

        emit ConfirmationRequired(msg.sender, _method, confirm[_method].count, _required);

        return false;
    }
  
    ///@dev token lockups
    ///@param _lockups token lock info array
    function setLockups(bytes memory _lockups) external onlyAdmin(){
        (Lockups[] memory lockups ) = abi.decode(_lockups, (Lockups[]));

        for( uint256 i = 0; i < lockups.length; i++ ){
            require( lockups[i].account != address(0), "TokenLock: NOT_ADDRESS");
            require( lockups[i].amount > 0, "TokenLock: NOT_AMOUNT");
            require( lockups[i].endTime > 0, "TokenLock: NOT_ENDTIME");

            IERC20(token).transferFrom(msg.sender, address(this), lockups[i].amount);

            uint256 duration = block.timestamp > lockups[i].endTime ? 0 : lockups[i].endTime-block.timestamp;

            lockupInfo[lockupIndex] = LockupInfo({
                amount : lockups[i].amount,
                timestamp : block.timestamp,
                duration : duration,
                account :lockups[i].account,
                index : lockupIndex   
            });

            accountToLockupIndex[lockups[i].account].push(lockupIndex);

            totalAmount += lockups[i].amount;
            lockupIndex++;
            lockupCount++;

            emit setLockupsEvent(lockups[i].account, lockups[i].amount, duration);
        }
    }

    ///@dev token lockup
    ///@param _account  eoa address
    ///@param _amount   token amount
    ///@param _endTime  endtime
    function setLockup(address _account, uint256 _amount, uint256 _endTime) external onlyAdmin(){
        require( _account != address(0), "TokenLock: NOT_ADDRESS");
        require( _amount > 0, "TokenLock: NOT_AMOUNT");
        require( _endTime > 0, "TokenLock: NOT_ENDTIME");

        IERC20(token).transferFrom(msg.sender, address(this), _amount);
        
        uint256 duration = block.timestamp > _endTime ? 0 : _endTime-block.timestamp;

        lockupInfo[lockupIndex] = LockupInfo({
            amount : _amount,
            timestamp : block.timestamp,
            duration : duration,
            account : _account,
            index : lockupIndex   
        });

        accountToLockupIndex[_account].push(lockupIndex);

        totalAmount += _amount;
        lockupIndex++;
        lockupCount++;

        emit setLockupEvent(_account, _amount, duration);
    }

    ///@dev remove lockup (admin)
    ///@param _account  target eoa address
    ///@param _receive  token receive address
    ///@param _lockupIndex lockup index
    function _removeLockup(address _account, address _receive, uint256 _lockupIndex) internal onlyAdmin(){
        require(_isLockInfo(_account), "TokenLock: NOT_LOCKINFO");
        require(_isLockIndex(_account, _lockupIndex), "TokenLock: NOT_LOCKINDEX");

        LockupInfo memory info = lockupInfo[_lockupIndex];

        IERC20(token).transferFrom(address(this), _receive, info.amount);

        delete lockupInfo[_lockupIndex];

        uint256 index = 0;
        for( index; index < accountToLockupIndex[_account].length; index++ ){
            if( accountToLockupIndex[_account][index] == _lockupIndex )
                break;            
        }

        if( accountToLockupIndex[_account].length > 0 ){
            accountToLockupIndex[_account][index] = accountToLockupIndex[_account][accountToLockupIndex[_account].length-1];
            accountToLockupIndex[_account].pop();
        } 

        totalAmount -= info.amount;       
        lockupCount--;
    }

    ///@dev remove lockups
    ///@param _lockups lockup info array
    ///@param _receive token receive address
     function removeLockups(bytes memory _lockups, address _receive) external nonReentrant onlyAdmin(){
        if (!_confirmCall(2, msg.sig, msg.data)) return;

        (LockupRemoveInfo[] memory lockups ) = abi.decode(_lockups, (LockupRemoveInfo[]));

        for( uint256 i = 0; i < lockups.length; i++ ){
            _removeLockup(lockups[i].account, _receive, lockups[i].index);
        }
    }

    ///@dev get all lockup info 
    ///@return list LockupInfo array list
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

    ///@dev lokcup info of account
    ///@param _account target eoa address
    ///@return list LockupResultInfo array list
    function getLockupsAccountAdmin(address _account) public view onlyAdmin returns(LockupResultInfo[] memory list){
        require(_isLockInfo(_account), "TokenLock: NOT_LOCKINFO");

        LockupResultInfo[] memory infoList = new LockupResultInfo[](accountToLockupIndex[_account].length);

        for( uint256 i = 0; i < accountToLockupIndex[_account].length; i++ ){
            infoList[i].amount = lockupInfo[accountToLockupIndex[_account][i]].amount;
            infoList[i].duration = lockupInfo[accountToLockupIndex[_account][i]].duration;
            infoList[i].timestamp = lockupInfo[accountToLockupIndex[_account][i]].timestamp;
            infoList[i].index = accountToLockupIndex[_account][i];
        }   

        return infoList;
    }

    ///@dev get lockup info
    ///@param _lockupIndex target lockup index
    ///@return info LockupInfo
    function getLockupAdmin(uint256 _lockupIndex) public view onlyAdmin returns(LockupInfo memory info){
        if( lockupInfo[_lockupIndex].amount != 0 ){
            info.amount = lockupInfo[_lockupIndex].amount;
            info.duration = lockupInfo[_lockupIndex].duration;
            info.timestamp = lockupInfo[_lockupIndex].timestamp;
            info.index = lockupInfo[_lockupIndex].index;
            info.account = lockupInfo[_lockupIndex].account;
        }
    }
    
    ///@dev get withdraw balance by lockupindex
    ///@param _lockupIndex lockup index
    ///@return amount possible amount
    function getBalanceAdmin(uint256 _lockupIndex) public view onlyAdmin returns(uint256 amount){
        uint256 curTime = block.timestamp;

        LockupInfo memory info = lockupInfo[_lockupIndex];

        if( info.timestamp+info.duration <= curTime )
            amount = info.amount;
        else
            amount = 0;
    }

    ///@dev get lokcups info
    ///@return list LockupResultInfo array list 
    function getLockups() public view returns(LockupResultInfo[] memory list){
        require(_isLockInfo(msg.sender), "TokenLock: NOT_LOCKINFO");

        LockupResultInfo[] memory infoList = new LockupResultInfo[](accountToLockupIndex[msg.sender].length);

        for( uint256 i = 0; i < accountToLockupIndex[msg.sender].length; i++ ){
            infoList[i].amount = lockupInfo[accountToLockupIndex[msg.sender][i]].amount;
            infoList[i].duration = lockupInfo[accountToLockupIndex[msg.sender][i]].duration;
            infoList[i].timestamp = lockupInfo[accountToLockupIndex[msg.sender][i]].timestamp;
            infoList[i].index = accountToLockupIndex[msg.sender][i];
        }   

        return infoList;
    }

    ///@dev get withdraw balance
    ///@param _lockupIndex lockup index
    ///@return amount possible amount
    function getBalance(uint256 _lockupIndex) public view onlyLock(_lockupIndex) returns(uint256 amount){
        uint256 curTime = block.timestamp;

        LockupInfo memory info = lockupInfo[_lockupIndex];

        if( info.timestamp+info.duration <= curTime )
            amount = info.amount;
        else
            amount = 0;
    }

    ///@dev lockup withdraw
    ///@param _lockupIndex lockup index 
    ///@return withdrawBalance withdraw tokenbalance
    function withdraw(uint256 _lockupIndex) public onlyLock(_lockupIndex) nonReentrant returns(uint256 withdrawBalance){
        uint256 balance = getBalance(_lockupIndex);

        require(balance > 0, "TokenLock: NOT_AMOUNT");
        require(IERC20(token).transferFrom(address(this), msg.sender, balance), "TokenLock: TRANSFER_ERR");

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

    ///@dev lockup withdraws 
    ///@return withdrawsBalance withdraw tokenbalance
    function withdraws() public nonReentrant returns(uint256 withdrawsBalance){
        require(_isLockInfo(msg.sender), "TokenLock: NOT_LOCKINFO");

        uint256 curTime = block.timestamp;
        uint256 withdrawCount;
        uint256 balance;

        for( uint256 i = 0; i < accountToLockupIndex[msg.sender].length; i++ ){
            if( lockupInfo[accountToLockupIndex[msg.sender][i]].timestamp+lockupInfo[accountToLockupIndex[msg.sender][i]].duration <= curTime ){
                balance += lockupInfo[accountToLockupIndex[msg.sender][i]].amount;
                withdrawCount++;                
            }
        }

        require(balance > 0, "TokenLock: NOT_AMOUNT");
        require(IERC20(token).transferFrom(address(this), msg.sender, balance), "TokenLock: TRANSFER_ERR");

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