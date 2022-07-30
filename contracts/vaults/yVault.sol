// SPDX-License-Identifier: MIT
pragma solidity ^0.8;

import "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import "@openzeppelin/contracts/token/ERC20/ERC20.sol";
import "@openzeppelin/contracts/utils/math/SafeMath.sol";
import "@openzeppelin/contracts/utils/Address.sol";
import "@openzeppelin/contracts/access/Ownable.sol";

import "../interfaces/yearn/IController.sol";

contract yVault is ERC20 {
    using SafeMath for uint256;
    using Address for address;

    IERC20 public token;

    uint public min = 9500;
    uint public max = 10000;

    address public governance;
    address public controller;

    uint8 internal deci;

    constructor(address _token, address _controller) 
    ERC20(
        string(abi.encodePacked("yearn ", ERC20(_token).name())), 
        string(abi.encodePacked("y", ERC20(_token).symbol()))
        )
    {
        token = IERC20(_token);
        governance = msg.sender;
        controller = _controller;
        deci = ERC20(_token).decimals();
    }

    function decimals() public view virtual override returns (uint8) {
        return deci;
    }

    function balance() public view returns(uint256){
        return token.balanceOf(address(this)).add(IController(controller).balanceOf(address(token)));
    }

    function setMin(uint256 _min) public {
        require(msg.sender == governance, "!governance");
        min = _min;
    }

    function setGovernance(address _governance) public {
        require(msg.sender == governance, "!governance");
        governance = _governance;
    }

    function setController(address _controller) public {
        require(msg.sender == governance, "!governance");
        controller = _controller;
    }

    function available() public view returns(uint256) {
        return token.balanceOf(address(this)).mul(min).div(max);
    }

    function earn() public {
        uint256 _bal = available();
        token.transfer(controller, _bal);
        IController(controller).earn(address(token), _bal);
    }

    function depositAll() external {
        deposit(token.balanceOf(msg.sender));
    }

    function deposit(uint256 _amount) public {
        uint256 _pool = balance();
        uint256 _before = token.balanceOf(address(this));
        token.transferFrom(msg.sender, address(this), _amount);
        uint256 _after = token.balanceOf(address(this));
        _amount = _after.sub(_before);
        uint shares = 0;
        if(totalSupply() == 0) {
            shares = _amount; 
        }else{
            shares = (_amount.mul(totalSupply())).div(_pool);
        }
        _mint(msg.sender, shares);
    }

    // Used to swap any borrowed reserve over the debt limit to liquidate to 'token'
    function harvest(address reserve, uint256 amount) external {
        require(msg.sender == controller, "!controller");
        require(reserve!= address(token), "token");
        IERC20(reserve).transfer(controller, amount);
    }

    function withdrawAll() public {
        withdraw(balanceOf(msg.sender));
    }

    function withdraw(uint256 _shares) public {
        uint256 r = (balance().mul(_shares)).div(totalSupply());
        _burn(msg.sender, _shares);

        uint256 b = token.balanceOf(address(this));

        if(b < r){
            uint256 _withdraw = r.sub(b);
            IController(controller).withdraw(address(token), _withdraw);
            uint256 _after = token.balanceOf(address(this));
            uint _diff = _after.sub(b);
            if(_diff < _withdraw){
                r = b.add(_diff);
            }
        }

        token.transfer(msg.sender, r);
    }

    function getPricePerShare() public view returns(uint256) {
        return balance().mul(1e18).div(totalSupply());
    }

}