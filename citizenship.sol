pragma solidity 0.8.4;

import "./sovereignty.sol";

// citizenship management system
contract CitizenshipManager {
  // the sovereignty under which this citizenship exists.
  Sovereignty sovereignty;

  // list of approved citizens
  address[] private citizen_list;
  function getCitizens() public view returns (address[] memory _citizens) {
    return citizen_list;
  }
  // mapping of who is a citizen and who is not
  mapping(address => uint) public citizens;
  mapping(uint => address) public citizensLookup;
  // count of how many citizens there are, including revoked citizenship
  uint public population;
  uint private last_id;

  // list of applicants
  mapping(address => uint) public applicants;

  constructor(address _sovereignty) public {
    sovereignty = Sovereignty(_sovereignty);
    // start citizenship ID at 1 so that 0 is non-citizen
    last_id = 1;
  }

  // citizenship grant structure
  struct Grant {
    // list of approvers for this citizen: maybe switch to array
    uint[] approvers;
    // date at which citizenship was granted
    uint grant_date;
    // date at which citizenship was terminated, if at all
    uint termination_date;
    // whether this was a special grant that came from the sovereignty itself
    bool special;
  }

  // list of citizenship grant information
  mapping(uint => Grant) public grants;
  uint lastGrantRequest;

  // record of the last time a citizen granted approval
  mapping(uint => uint) public lastApproved;

  // adds an applicant to the list
  function applyForCitizenship() public {
    address addr = msg.sender;
    // check if applicant is already a citizen or pending grant
    require(citizens[addr] == 0 && applicants[addr] == 0);
    sovereignty.processFee(msg.sender, sovereignty.applicationFee());
    // add to list of applicants
    applicants[addr] = lastGrantRequest;
    lastGrantRequest += 1;
  }

  // checks if address is a citizen
  function isCitizen(address _addr) public view returns (bool) {
    return citizens[_addr] > 0;
  }
  // checks if address is a citizen
  function isCitizen(uint _id) public view returns (bool) {
    return citizensLookup[_id] != address(0);
  }

  // checks if address is an applicant
  function isApplicant(address _addr) public view returns (bool) {
    return applicants[_addr] == 1;
  }

  // approve a citizen grant request and return their id if enough approvals have collected
  function approveApplicant(address _addr, uint  approver) public returns (uint _id) {
    // check if applicant is already a citizen
    require(citizens[_addr] == 0);
    require(canApproveCitizenship(approver));
    // check if applicant
    uint gid = applicants[_addr];
    require(gid != 0);
    Grant storage grant = grants[gid];
    grant.approvers.push(approver);
    // check if enough people have approved
    if (grant.approvers.length > minimum_approvers()) {
      grant.grant_date = block.timestamp;
      uint id = _grantCitizenship(_addr);
      emit CitizenshipGranted(id, _addr, grant.approvers);
      return id;
    }
    return 0;
  }

  function sovereignGrant(address _addr) public returns (uint _grant_id) {
      require(msg.sender == address(sovereignty));
      require(citizens[_addr] == 0);
      uint id = population;
      population += 1;
      uint gid = applicants[_addr];
      require(gid != 0);
      Grant storage grant = grants[gid];
      grant.grant_date = block.timestamp;
      grant.special = true;
      citizens[_addr] = id;
      citizensLookup[id] = _addr;
      emit SovereignGrant(id, _addr);
      return id;
  }

  function _grantCitizenship(address _addr) private returns (uint _grant_id) {
    uint grant_id = last_id;
    last_id++;

    // grant citizenship to applicant and add to reverse lookup
    citizens[_addr] = grant_id;
    // this isn't correct
    citizensLookup[grant_id] = _addr;

    citizen_list.push(_addr);
    population += 1;
    return grant_id;
  }
  // how many approvers are needed to grant citizenship status
  function minimum_approvers() public returns (uint minimum) {
    uint cap = population / 1000;
    if (cap > 5) return 5;
    if (cap < 1) return 1;
  }

  // check if a citizen is able to approve someone else for citizenship: should allow votes to change some parameters
  function canApproveCitizenship(uint _id) public view returns (bool can_approve){
    if (citizensLookup[_id] == address(0)) return false;

    Grant storage grant = grants[_id];

    // Account must be the lesser of 10% of the current age of the sovereignty or five years.
    uint min_age = (block.timestamp - sovereignty.founding()) / 10;
    if (min_age > 1460 days) min_age = 1460 days;

    // Account cannot have already approved someone for citizenship within the lesser of the past year, or half the current age of the sovereignty.
    uint approval_lockout = (block.timestamp - sovereignty.founding()) / 5;
    if (approval_lockout > 1460 days) approval_lockout = 1460 days;

    return (block.timestamp - grant.grant_date) >= min_age && (block.timestamp - lastApproved[_id]) > approval_lockout;
  }

  // While the idea of revoking citizenship can be problematic, it can be useful, if designed right. For instance, citizens could age out, etc. But what happens if lifespans increase?
  function revoke_citizenship(uint _id) public {
    require(msg.sender == address(sovereignty));
    address addr = citizensLookup[_id];
    citizens[addr] = 0;
    citizensLookup[_id] = address(0);
    uint i = 0;
    bool found = false;
    while (i < citizen_list.length) {
      if (citizen_list[i] == addr) {
        found = true;
        break;
      }
      i++;
    }
    require(found);
    // Scrap explainig the process of deleting and swapping with the last element
    address element = citizen_list[i];
    citizen_list[i] = citizen_list[citizen_list.length - 1];
    citizen_list.pop();
    // Broken: Need to add a lookup table to identify grant ID from user ID
    Grant storage grant = grants[citizens[addr]];
    grant.termination_date = block.timestamp;
    emit CitizenshipRevoked(_id);
  }
  // still need to add a refactor function which transfers citizenship from one address to another
  event SovereignGrant(uint _id, address _granted_to);
  event CitizenshipGranted(uint _id, address _granted_to, uint[] _approvers);
  event CitizenshipRevoked(uint _id);
}

// Manages properties of each citizen.
contract CitizenManager {
  // list of potential properties such as whether the citizen is an arbiter or counselperson
  mapping (uint => uint64) public properties;
  // amount of trust this citizen has built up - given out based on age of the account, and other things, and taken based on arbitration
  // under arbitration, trust can be burned to mint the resource token, which can be used to pay for disputes
  // maybe build trust each time there's a citizen to citizen transaction?
  mapping (uint => uint) public trust;
  Sovereignty sovereignty;

  constructor(address _sovereignty) {
    sovereignty = Sovereignty(_sovereignty);
  }

  function increaseTrust(uint _id, uint _amt) public returns (uint _balance) {
    require(msg.sender == address(sovereignty));
    trust[_id] += _amt;
    return trust[_id];
  }

  function distributeTrustBonuses(uint _bonus) public {
    require(msg.sender == address(sovereignty));
    CitizenshipManager citizenship = sovereignty.citizenship();
    // Not sure if it's better to do a loop like this or traverse through addresses. Probably depends on the population size.
    uint pop = citizenship.population();
    for (uint i = 0; i < pop; i++) {
      if (citizenship.isCitizen(i)) {
        trust[i] += _bonus;
      }
    }
  }

  function decreaseTrust(uint _id, uint _amt) public returns (uint _balance) {
    require(msg.sender == address(sovereignty));
    require(sovereignty.citizenship().isCitizen(_id));
    require(trust[_id] >= _amt);
    trust[_id] -= _amt;
    return trust[_id];
  }
}
