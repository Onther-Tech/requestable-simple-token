pragma solidity ^0.4.24;

import "openzeppelin-solidity/contracts/math/SafeMath.sol";
import "openzeppelin-solidity/contracts/ownership/Ownable.sol";

contract RequestableSimpleTokenWithNoOwnership {
  using SafeMath for *;

  // `totalSupply` is stored at bytes32(1).
  uint public totalSupply;

  // `balances[addr]` is stored at keccak256(bytes32(addr), bytes32(2)).
  mapping(address => uint) public balances;

  /* Events */
  event Transfer(address _from, address _to, uint _value);
  event Mint(address _to, uint _value);
  event Request(bool _isExit, address _requestor, bytes32 _trieKey, bytes32 _trieValue);

  function transfer(address _to, uint _value) public {
    balances[msg.sender] = balances[msg.sender].sub(_value);
    balances[_to] = balances[_to].add(_value);

    emit Transfer(msg.sender, _to, _value);
  }

  function mint(address _to, uint _value) public {
    totalSupply = totalSupply.add(_value);
    balances[_to] = balances[_to].add(_value);

    emit Mint(_to, _value);
    emit Transfer(0x00, _to, _value);
  }

  // User can get the trie key of one's balance and make an enter request directly.
  function getBalanceTrieKey(address who) public pure returns (bytes32) {
    return keccak256(bytes32(who), bytes32(1));
  }

  function applyRequestInRootChain(
    bool isExit,
    uint256 requestId,
    address requestor,
    bytes32 trieKey,
    bytes32 trieValue
  ) public returns (bool success) {
    // TODO: adpot RootChain
    // require(msg.sender == address(rootchain));
    // require(!getRequestApplied(requestId)); // check double applying

    if (isExit) {
      // exit must be finalized.      
      if(bytes32(0) == trieKey) {
        // no one can exit `totalSupply` variable.
        // but do nothing to return true.
      } else if (keccak256(bytes32(requestor), bytes32(1)) == trieKey) {
        // this checks trie key equals to `balances[requestor]`.
        // only token holder can exit one's token.
        // exiting means moving tokens from child chain to root chain.
        balances[requestor] += uint(trieValue);
      } else {
        // cannot exit other variables.
        // but do nothing to return true.
      }
    } else {
      // apply enter
      if(bytes32(0) == trieKey) {
        // no one can enter `totalSupply` variable.
        revert();
      } else if (keccak256(bytes32(requestor), bytes32(1)) == trieKey) {
        // this checks trie key equals to `balances[requestor]`.
        // only token holder can enter one's token.
        // entering means moving tokens from root chain to child chain.
        require(balances[requestor] >= uint(trieValue));
        balances[requestor] -= uint(trieValue);
      } else {
        // cannot apply request on other variables.
        revert();
      }
    }

    emit Request(isExit, requestor, trieKey, trieValue);

    // TODO: adpot RootChain
    // setRequestApplied(requestId);
    return true;
  }

  // this is only called by NULL_ADDRESS in child chain
  // when i) exitRequest is initialized by startExit() or
  //     ii) enterRequest is initialized
  function applyRequestInChildChain(
    bool isExit,
    uint256 requestId,
    address requestor,
    bytes32 trieKey,
    bytes32 trieValue
  ) external returns (bool success) {
    // TODO: adpot child chain
    // require(msg.sender == NULL_ADDRESS);

    if (isExit) {
      if(bytes32(0) == trieKey) {
        // no one can exit `totalSupply` variable.
        revert();
      } else if (keccak256(bytes32(requestor), bytes32(1)) == trieKey) {
        // this checks trie key equals to `balances[tokenHolder]`.
        // only token holder can exit one's token.
        // exiting means moving tokens from child chain to root chain.

        // revert provides a proof for `exitChallenge`.
        require(balances[requestor] >= uint(trieValue));

        balances[requestor] -= uint(trieValue);
      } else { // cannot exit other variables.
        revert();
      }
    } else { // apply enter
      if(bytes32(0) == trieKey) {
        // no one can enter `totalSupply` variable.
      } else if (keccak256(bytes32(requestor), bytes32(1)) == trieKey) {
        // this checks trie key equals to `balances[tokenHolder]`.
        // only token holder can enter one's token.
        // entering means moving tokens from root chain to child chain.
        balances[requestor] += uint(trieValue);
      } else {
        // cannot apply request on other variables.
      }
    }

    emit Request(isExit, requestor, trieKey, trieValue);
    return true;
  }

}
