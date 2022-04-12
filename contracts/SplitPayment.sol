//SPDX-License-Identifier: Unlicense
pragma solidity ^0.8.0;

import "@openzeppelin/contracts/access/Ownable.sol";
import "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import "@openzeppelin/contracts/token/ERC20/utils/SafeERC20.sol";

/// @notice SplitPayment is a contract that allows to split Ether & ERC20 payments among a list of accounts
contract SplitPayment is Ownable {
    using SafeERC20 for IERC20;

    /// @notice list of accounts
    mapping(address => uint) public accounts;
    uint public accountLen;
    
    /// @notice eth pools
    mapping (uint => uint) public ethPools;
    uint public ethPoolLen;

    /// @notice erc20 token pools
    mapping (uint => mapping(address => uint)) public tokenPools;
    uint public tokenPoolLen;

    event Deposit(uint indexed pid, address indexed user, uint amount);
    event Withdraw(uint indexed pid, address indexed user, uint amount);
    event DepositToken(uint indexed pid, address indexed user, address indexed token, uint amount);
    event WithdrawToken(uint indexed pid, address indexed user, address indexed token, uint amount);

    constructor(address[] memory _accounts, uint[] memory _shares) {
        updateAccounts(_accounts, _shares);
    }

    receive () external payable {
        deposit();
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

    /// @notice deposit eth
    function deposit() public payable {
        ethPools[ethPoolLen] = msg.value;
        emit Deposit(ethPoolLen ++, msg.sender, msg.value);
    }

    /**
     * @notice withdraw eth of specific pool
     * @param pid:uint eth pool id 
     */
    function withdraw(uint pid) external {
        uint amount = ethPools[pid] * accounts[msg.sender] / 1e8;
        payable(msg.sender).transfer(amount);
        emit Withdraw(pid, msg.sender, amount);
    }

    /**
     * @notice deposit token 
     * @param token:address token address
     * @param amount:uint amount of token
     */ 
    function depositToken(address token, uint amount) external {
        tokenPools[tokenPoolLen ++][token] = amount;
        IERC20(token).safeTransferFrom(msg.sender, address(this), amount);

        emit DepositToken(tokenPoolLen ++, msg.sender, token, amount);
    }

    /** @notice withdraw token of specific pool
     * @param pid:uint token pool id
     * @param token:address token address
     */
    function withdrawToken(uint pid, address token) external {
        uint amount = tokenPools[pid][token] * accounts[msg.sender] / 1e8;
        IERC20(token).safeTransfer(msg.sender, amount);
        emit WithdrawToken(pid, msg.sender, token, amount);
    }
}
