//SPDX-License-Identifier: Unlicense
pragma solidity ^0.8.0;

import "@openzeppelin/contracts/access/Ownable.sol";
import "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import "@openzeppelin/contracts/token/ERC20/utils/SafeERC20.sol";

/// @notice SplitPayment is a contract that allows to split Ether & ERC20 payments among a list of accounts
contract SplitPayment is Ownable {
    using SafeERC20 for IERC20;

    /// @notice list of accounts with shares. shares times by 1e6. ex: 1% is 1e6
    mapping(address => uint) public accounts;
    uint public accountLen;

    /// @notice Info of Pool
    struct PoolInfo {
        uint balance; // deposit amount
        uint startTime; // deposit time
        uint streamingTime; // streaming time
        mapping (address => uint) withdrawnAmount; // withdrawn amount of user
    }

    /// @notice eth pools
    mapping (uint => PoolInfo) public ethPools;
    uint public ethPoolLen;

    /// @notice erc20 token pools
    mapping (uint => mapping(address => PoolInfo)) public tokenPools;
    uint public tokenPoolLen;

    event Deposit(uint indexed pid, address indexed user, uint amount, uint streamingTime);
    event Withdraw(uint indexed pid, address indexed user, uint amount);
    event DepositToken(uint indexed pid, address indexed user, address indexed token, uint amount, uint streamingTime);
    event WithdrawToken(uint indexed pid, address indexed user, address indexed token, uint amount);

    constructor(address[] memory _accounts, uint[] memory _shares) {
        updateAccounts(_accounts, _shares);
    }

    receive () external payable {
        deposit(0);
    }

    /**
     * @notice update accounts with shares
     * @param _accounts:address[] list of accounts
     * @param _shares:uint[] list of shares 
     */
    function updateAccounts(address[] memory _accounts, uint[] memory _shares) public onlyOwner {
        uint _accountLen = _accounts.length;
        uint _shareLen = _shares.length;

        // Array Length Check
        require(_accountLen > 0, "SP: empty array");
        require(_accountLen == _shareLen, "SP: different lenths");

        // Shares Validation Check
        uint shareSum;
        for (uint i; i < _shareLen; i ++) 
            shareSum += _shares[i];
        require(shareSum == 1e8, "SP: wrong shares");

        // Update accounts
        for (uint i; i < _accountLen; i ++)
            accounts[_accounts[i]] = _shares[i];
        accountLen = _accountLen;
    }

    /** @notice deposit eth
     * @param streamingTime:uint streaming time of deposit
     */
    function deposit(uint streamingTime) public payable {
        PoolInfo storage pool = ethPools[ethPoolLen];
        pool.balance = msg.value;
        pool.startTime = block.timestamp;
        pool.streamingTime = streamingTime;
        emit Deposit(ethPoolLen ++, msg.sender, msg.value, streamingTime);
    }

    /**
     * @notice withdraw eth of specific pool
     * @param pid:uint eth pool id 
     */
    function withdraw(uint pid) external {
        PoolInfo storage pool = ethPools[pid];
        uint withdrawableAmount = getWithdrawableAmount(pool.balance, pool.startTime, pool.streamingTime);
        uint amount = withdrawableAmount - pool.withdrawnAmount[msg.sender];
        pool.withdrawnAmount[msg.sender] += amount;
        payable(msg.sender).transfer(amount);

        emit Withdraw(pid, msg.sender, amount);
    }

    /**
     * @notice deposit token 
     * @param token:address token address
     * @param amount:uint amount of token
     * @param streamingTime:uint streaming time of deposit
     */ 
    function depositToken(address token, uint amount, uint streamingTime) external {
        PoolInfo storage pool = tokenPools[tokenPoolLen][token];
        pool.balance = amount;
        pool.startTime = block.timestamp;
        pool.streamingTime = streamingTime;
        IERC20(token).safeTransferFrom(msg.sender, address(this), amount);

        emit DepositToken(tokenPoolLen ++, msg.sender, token, amount, streamingTime);
    }

    /** @notice withdraw token of specific pool
     * @param pid:uint token pool id
     * @param token:address token address
     */
    function withdrawToken(uint pid, address token) external {
        PoolInfo storage pool = tokenPools[pid][token];
        uint withdrawableAmount = getWithdrawableAmount(pool.balance, pool.startTime, pool.streamingTime);
        uint amount = withdrawableAmount - pool.withdrawnAmount[msg.sender];
        pool.withdrawnAmount[msg.sender] += amount;
        IERC20(token).safeTransfer(msg.sender, amount);

        emit WithdrawToken(pid, msg.sender, token, amount);
    }

    /** @notice get withdrawable amount of token or eth
     * @param balance:uint amount of token or eth
     * @param startTime:uint start time of deposit
     * @param streamingTime:uint streaming time of deposit
     */
    function getWithdrawableAmount(uint balance, uint startTime, uint streamingTime) internal view returns (uint) {
        uint withdrawableAmount = balance * accounts[msg.sender] / 1e8;
        if (streamingTime != 0) {
            uint streamedTime = block.timestamp - startTime > streamingTime ? streamingTime : block.timestamp - startTime;
            withdrawableAmount = withdrawableAmount *  streamedTime / streamingTime;
        }
        return withdrawableAmount;
    }
}
