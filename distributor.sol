pragma solidity 0.8.4;

import "./citizenship.sol";
import "./sovereignty.sol";
import "./resource.sol";

// used to distribute UBI to citizens
contract Distributor {
  Sovereignty sovereignty;
  bool distributing;

  // list of fees charged to citizens
  mapping (address => uint) public fees;
  // amount of funds collectable
  mapping (address => uint) public collectable;

  function charge(address _addr, uint fee) public {
    require(address(sovereignty) == msg.sender);
    require(sovereignty.citizenship().isCitizen(_addr));
    // When refactoring a citizen, it's important to make sure that fees are transferred too
    fees[_addr] += fee;
  }

  constructor(address _sovereignty) public {
    sovereignty = Sovereignty(_sovereignty);
  }

  // distribute resource for UBI
  function distribute() public returns (uint _distributed) {
    require(!distributing);
    distributing = true;
    CitizenshipManager citizenship = sovereignty.citizenship();
    // Can't access citizen_list directly, will need to use accessors to deal with stuff.
    address[] memory list = citizenship.getCitizens();
    uint full_payout = sovereignty.resource().balanceOf(address(this)) / list.length;
    uint total_distributed_ubi;
    for (uint i = 0; i < list.length; i++) {
      address payee = list[i];
      // distribute UBI
      uint fee = fees[payee];
      if (fee > full_payout) {
        fees[payee] = fee - full_payout;
      } else {
        uint payout = full_payout - fee;
        fees[payee] = 0;
        if (payout > 0) {
          sovereignty.resource().transfer(payee, payout);
          total_distributed_ubi += payout;
        }
      }
    }
    distributing = false;
    return total_distributed_ubi;
  }
}
