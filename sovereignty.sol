pragma solidity 0.8.4;

import "./resource.sol";
import "./citizenship.sol";
import "./distributor.sol";
import "./governance.sol";

/* The main function of the sovereignty contract is to be a hub for the other components. All other components will refer back to this contract for addresses to other components, allowing for modular changes. */

// defines a sovereignty
contract Sovereignty is Governed {
  address owner;

  // name of the sovereignty
  string name;

  // the sovereign resource of this sovereignty
  SovereignResource public resource;
  // the citizenship cotract of this sovereignty
  CitizenshipManager public citizenship;
  // the citizen contract for this sovereignty
  CitizenManager public citizens;
  // distributor contract for resources
  Distributor public distributor;
  // governor contract
  Governor public governor;
  // arbitration contract
  Arbitrator public arbitrator;
  // the founding date of this sovereignty
  uint public founding;

  uint private lastDistribution;

  // daily ubi rate
  uint public dailyUBI = 10;
  // citizens will get five trust a day
  uint public dailyTrust = 5;
  // fraction of trust generated from sending resource from one citizen to another: 1/100th of one percent increments
  uint public transferFraction = 10;

  // list of fees
  uint public applicationFee = 300;
  uint public complaintFee = 25; // per plaintiff-defendant

  constructor() public {
    owner = msg.sender;
    name = "First Sovereignty";
    lastDistribution = block.timestamp;
  }

  function set_citizenship_manager(address _addr) public {
    require(msg.sender == owner);
    require(address(citizenship) == address(0));
    citizenship = CitizenshipManager(_addr);
  }

  function set_citizens_manager(address _addr) public {
    require(msg.sender == owner);
    require(address(citizens) == address(0));
    citizens = CitizenManager(_addr);
  }

  function set_resource(address _addr) public {
    require(msg.sender == owner);
    require(address(resource) == address(0));
    resource = SovereignResource(_addr);
  }

  function set_distributor(address _addr) public {
    require(msg.sender == owner);
    require(address(distributor) == address(0));
    distributor = Distributor(_addr);
  }

  function set_governor(address _addr) public {
    require(msg.sender == owner);
    require(address(governor) == address(0));
    governor = Governor(_addr);
  }

  function set_arbitrator(address _addr) public {
    require(msg.sender == owner);
    require(address(arbitrator) == address(0));
    arbitrator = Arbitrator(_addr);
  }

  // check if a resource transaction is between two citizens, and convert some resource to trust
  function txProcess(address _from, address _to, uint _value) public {
    require(msg.sender == address(resource));
    if (citizenship.isCitizen(_from) && citizenship.isCitizen(_to)) {
      uint amt = (_value * transferFraction) / 1000;
      // draw from future UBI and add to trust
      citizens.increaseTrust(citizenship.citizens(_from), amt);
      distributor.charge(_from, amt);
    }
  }

  // compensate one citizen via the balance of another
  function compensate(uint _from, uint _to, uint _amt) public {
    require(msg.sender == address(arbitrator));
    address addr = citizenship.citizensLookup(_to);
    // reduce trust from the citizen, mint new resource token, and transfer it to the other user
    citizens.decreaseTrust(_from, _amt);
    resource.mint(addr, _amt);
  }
  // increases supply of resource and amount of trust, based on how much time has passed, and distribute
  function UBI() public returns (uint total_distributed) {
      // Get number of whole days since last mint
      uint lapse = (block.timestamp - lastDistribution) / 1 days;
      require(lapse > 0);

      // Update last mint adjusting for remainder of a day.
      lastDistribution = block.timestamp - (1 days * lapse);

      uint supply_increase = lapse * dailyUBI * citizenship.population();

      // mint more resource which will then be added to the UBI distribution
      resource.mint(address(distributor), supply_increase);

      // distribute trust to all citizens
      uint trust_bonus = lapse * dailyTrust;
      citizens.distributeTrustBonuses(trust_bonus);
      // trigger distribution of UBI
      return distributor.distribute();
  }
  // charge a citizen a fee and burn the resource
  function processFee(address _addr, uint _amt) public {
    require(msg.sender == address(governor) || msg.sender == address(arbitrator) || msg.sender == address(citizenship));
    resource.chargeBurn(_addr, _amt);
  }

  // governance functionality
  function onResolve(uint _rid) public virtual {
    require(msg.sender == address(governor));
    // doesn't do anything right now
  }
}
