pragma solidity 0.8.4;

import "./sovereignty.sol";
import "./citizenship.sol";

// controls voting and system settings
contract Governor {
  Sovereignty sovereignty;
  constructor(address _sovereignty) public {
    sovereignty = Sovereignty(_sovereignty);
  }
}

contract Arbitrator {
  Sovereignty sovereignty;

  struct Complaint {
    address[] plaintiffs;
    address[] defendants;
    string cause_of_action;
    bool rejected;
    uint claim;
    uint arbitration;
  }

  struct Arbitration {
    uint complaint;
    // selected arbiters for the case
    uint[] arbiters;
    uint resolution;
  }

  struct Resolution {
    uint complaint;
  }

  mapping (uint => Complaint) complaints;
  uint public lastComplaint;

  mapping (uint => Arbitration) arbitrations;
  uint public lastArbitration;

  mapping (uint => Resolution) resolutions;
  uint public lastResolution;

  constructor(address _sovereignty) {
    sovereignty = Sovereignty(_sovereignty);
  }
  // file a complaint
  function fileComplaint(address[] calldata _plaintiffs, address[] calldata _defendants, string calldata _coa, uint _claim) public {
    Complaint storage complaint = complaints[lastComplaint];
    lastComplaint += 1;
    complaint.cause_of_action = _coa;
    complaint.claim = _claim;
    complaint.plaintiffs = _plaintiffs;
    complaint.defendants = _defendants;
    sovereignty.processFee(msg.sender, sovereignty.complaintFee() * (_plaintiffs.length + _defendants.length));
  }
}
