pragma solidity 0.8.4;
import "./sovereignty.sol";
import "./distributor.sol";

contract SovereignResource {
    string public name;
    string public symbol;
    uint8 public decimals;
    uint public totalSupply;

    Sovereignty sovereignty;

    mapping (address => uint256) public balanceOf;
    mapping (address => mapping (address => uint256)) public allowance;

    constructor(address _sovereignty) public {
        name = "First Sovereign Resource";
        symbol = "FSR";
        decimals = 18;
        totalSupply = 0;
        sovereignty = Sovereignty(_sovereignty);
    }

    // This token isn't deflationary and doesn't rebase. Instead, the amount that a person would get from the distributor is decreased as a fee.
    function transfer(address _to, uint256 _value) public returns (bool) {
        require(balanceOf[msg.sender] >= _value && _value > 0);
        balanceOf[msg.sender] -= _value;
        balanceOf[_to] += _value;
        sovereignty.txProcess(msg.sender, _to, _value);
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
        sovereignty.txProcess(_from, _to, _value);
        emit Transfer(_from, _to, _value);
        return true;
    }

    function chargeBurn(address _from, uint _amt) public {
      require(msg.sender == address(sovereignty));
      require(balanceOf[_from] >= _amt);
      balanceOf[_from] -= _amt;
      totalSupply -= _amt;
      emit Transfer(_from, address(0), _amt);
    }

    function mint(address _to, uint _amt) public {
      require(msg.sender == address(sovereignty));
      totalSupply += _amt;
      balanceOf[_to] += _amt;
      emit Transfer(address(0), _to, _amt);
    }

    event Transfer(address indexed _from, address indexed _to, uint256 _value);
    event Approval(address indexed _owner, address indexed _spender, uint256 _value);
}
