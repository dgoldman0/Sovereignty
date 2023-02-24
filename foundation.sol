pragma solidity 0.8.4;
import "./sovereignty.sol";
import "./resource.sol";

/* These contracts establish the BASICS Foundation, a foundation that works to provide the basic needs of food, clothing, and shelter, to everyone. */

// Foundation voting, including changing conversion rates will be done through citizenship (or representatives), but access to funds will be determined
contract Foundation {
  Sovereigty public sovereignty;
  ForgableCurrency public currency;

  // percent of resource to be returned to distributor upon forging
  uint public percentDistributed = 25;
  // conversion rate of resource required for one BSIC
  uint public forgeRate = 10;
  // cost to register as a smith; base rate is 0.1 ETH
  uint public smithFee = 100000000000000000;

  // Function to receive Ether. msg.data must be empty
  receive() external payable {}

  // Fallback function is called when msg.data is not empty
  fallback() external payable {}

  function getBalance() public view returns (uint) {
      return address(this).balance;
  }
}

contract ForgableCurrency {
    Foundation foundation;
    string public name = 'BASICS';
    string public symbol = 'BSIC';
    uint public decimals = 18;
    uint public totalSupply;
    address owner;

    mapping(address => uint256) public balanceOf;
    mapping (address => mapping (address => uint256)) public allowance;

    // indicates whether this address has paid the smith fee
    mapping (address => bool) public canSmith;
    // number of registered smiths
    uint public smithCount;
    // total amount of resource used
    uint public materialUsed;
    // time of last mint
    uint public lastMint;

    constructor() public {
        // Initial supply of 100,000 BSIC
        totalSupply = 100000000000000000000000;
        balanceOf[msg.sender] = totalSupply;
        owner = msg.sender;
    }

    function setFoundation(address _addr) public {
      require(msg.sender == owner);
      require(address(foundation) == address(0));
      foundation = Foundation(_addr);
    }

    function transfer(address _to, uint256 _value) public returns (bool) {
        require(balanceOf[msg.sender] >= _value && _value > 0);
        balanceOf[msg.sender] -= _value;
        balanceOf[_to] += _value;
        emit Transfer(msg.sender, _to, _value);
        return true;
    }

    function approve(address _spender, uint256 _value) public returns (bool) {
        allowance[msg.sender][_spender] = _value;
        emit Approval(msg.sender, _spender, _value);
        return true;
    }

    function transferFrom(address _from, address _to, uint256 _value) public returns (bool) {
        require(_value <= balanceOf[_from] && _value <= allowance[_from][msg.sender]);
        balanceOf[_from] -= _value;
        balanceOf[_to] += _value;
        allowance[_from][msg.sender] -= _value;
        emit Transfer(_from, _to, _value);
        return true;
    }

    // internal mint function
    function _mint(address _to, uint _amt) internal {
      totalSupply += _amt;
      balanceOf[_to] += amt;
      emit Transfer(address(0), _to, _amt);
    }

    // mint new narrow currency in return for resource token
    function forge(uint _amt) external returns (uint256 amt) {
      require(_amt > 0);
      SovereignResource resource = foundation.sovereignty().resource();
      uint distributed = _amt * foundation.percentDistributed() / 100;
      resource.transfer(address(foundation.sovereignty().distributor()), distributed);
      uint remainder = _amt - distributed;
      resource.transfer(msg.sender, address(foundation), remainder);
      _mint(msg.sender, _amt / foundation.forgeRate());
      lastMint = block.timestamp;
    }

    function conversionRate() external view returns (uint256 rate) {
      return foundation.forgeRate();
    }

    function smithFee() external view returns (uint256 paid) {
      return foundation.smithFee();
    }

    // register as a smith and transfer fee to the foundation
    function paySmithingFee() external payable returns (bool fee) {
      require(!canSmith[msg.sender]);
      require(msg.value == foundation.smithFee());
      (bool sent, bytes memory data) = address(foundation).call{value: msg.value}("");
      require(sent, "Failed to send Ether");
      canSmith[msg.sender] = true;
    }

    event Forged(address indexed to, uint cost, uint amt);
    event NewSmith(address indexed, uint fee);
    event Transfer(address indexed from, address indexed to, uint256 value);
    event Approval(address indexed _owner, address indexed _spender, uint256 _value);
}
