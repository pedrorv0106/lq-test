//SPDX-License-Identifier: Unlicense
pragma solidity ^0.8.0;

import "@openzeppelin/contracts/access/Ownable.sol";

// import "hardhat/console.sol";

contract SplitPayment is Ownable {
    
    mapping(address => uint) public accounts;
    uint public accountLen;
    // uint 
    mapping (uint => uint) public ethPools;
    // mapping (uint => mapping(address => uint)) public tokenPools;
    uint public ethPoolLen;

    event Deposit(uint indexed pid, address indexed user, uint amount);
    event Withdraw(uint indexed pid, address indexed user, uint amount);

    constructor(address[] memory _accounts, uint[] memory _shares) {
        updateAccounts(_accounts, _shares);
    }

    receive () external payable {
        
    }

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

    function deposit() public payable {
        ethPools[ethPoolLen] = msg.value;
        emit Deposit(ethPoolLen ++, msg.sender, msg.value);
    }

    function withdraw(uint pid) external {
        uint amount = ethPools[pid] * accounts[msg.sender] / 1e8;
        payable(msg.sender).transfer(amount);
        emit Withdraw(pid, msg.sender, amount);
    }


    // function greet() public view returns (string memory) {
    //     return greeting;
    // }

    // function setGreeting(string memory _greeting) public {
    //     console.log("Changing greeting from '%s' to '%s'", greeting, _greeting);
    //     greeting = _greeting;
    // }
}
