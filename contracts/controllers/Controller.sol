// SPDX-License-Identifier: MIT
pragma solidity ^0.8;

import "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import "@openzeppelin/contracts/utils/math/SafeMath.sol";
import "@openzeppelin/contracts/utils/Address.sol";

import "../interfaces/yearn/Strategy.sol";
import "../interfaces/yearn/Converter.sol";
import "../interfaces/yearn/OneSplitAudit.sol";

contract Controller {
    using SafeMath for uint256;
    using Address for address;

    address public governance;
    address public strategist;

    address public onesplit;
    address public rewards;

    mapping(address=>address) public vaults;
    mapping(address=>address) public strategies;
    mapping(address=> mapping(address=>address)) public converters;

    mapping(address=>mapping(address=>bool)) public approvedStrategies;

    uint256 public split = 500;
    uint256 public constant max = 10000;

    constructor(address _rewards) {
        governance = msg.sender;
        strategist = msg.sender;
        onesplit = address(0x50FDA034C0Ce7a8f7EFDAebDA7Aa7cA21CC1267e);
        rewards = _rewards;
    }

    function setRewards(address _rewards) external {
        require(msg.sender == governance, "!governance");
        rewards = _rewards;
    }

    function setStrategist(address _strategist) external {
        require(msg.sender == governance, "!governance");
        strategist = _strategist;
    }

    function setSplit(uint256 _split) external {
        require(msg.sender == governance, "!governance");
        split = _split;
    }

    function setOnesplit(address _onesplit) external {
        require(msg.sender == governance, "!governance");
        onesplit = address(_onesplit);
    }

    function setGovernance(address _governance) external {
        require(msg.sender == governance, "!governance");
        governance = _governance;
    }

    function setVault(address _token, address _vault) external {
        require(msg.sender == governance || msg.sender == strategist, "unauthorised");
        require(vaults[_token] == address(0), "vault");
        vaults[_token] = _vault;
    }

    function approveStrategy(address _token, address _strategy) external {
        require(msg.sender == governance , "!governance");
        approvedStrategies[_token][_strategy] = true;
    }

    function revokeStrategy(address _token, address _strategy) external {
        require(msg.sender == governance, "!governance");
        approvedStrategies[_token][_strategy] = false;
    }

    function setConverter(address _input, address _output, address _converter) public {
        require(msg.sender == strategist || msg.sender == governance, "unauthorised");
        converters[_input][_output] = _converter;
    }

    function setStrategy(address _token, address _strategy) public {
        require(msg.sender == strategist || msg.sender == governance, "unauthorised");
        require(approvedStrategies[_token][_strategy]==true, "!approved");

        address _current = strategies[_token];
        if(_current != address(0)){
            Strategy(_current).withdrawAll();
        }
        strategies[_token]=_strategy;
    }

    function earn(address _token, uint256 _amount) public {
        address _strategy = strategies[_token];
        address _want = Strategy(_strategy).want();
        if(_want != _token){
            address converter = converters[_token][_want];
            IERC20(_token).transfer(converter, _amount);
            _amount = Converter(converter).convert(_strategy);
            IERC20(_want).transfer(_strategy, _amount);
        } else {
            IERC20(_token).transfer(_strategy, _amount);
        }
        Strategy(_strategy).deposit();
    }

    function balanceOf(address _token) public view returns(uint256){
        return Strategy(strategies[_token]).balanceOf();
    }

    function withdrawAll(address _token) public {
        require(msg.sender == strategist || msg.sender == governance, "!unauthorised");
        Strategy(strategies[_token]).withdrawAll();
    }

    function inCaseTokensGetStuck(address _token, uint256 _amount) public {
        require(msg.sender == strategist || msg.sender == governance , "!unauthorised");
        IERC20(_token).transfer(msg.sender, _amount);
    }

    function inCaseStrategyTokenGetStruck(address _strategy, uint256 _token) public {
        Strategy(_strategy).withdraw(_token);
    }

    function getExpectedReturn(address _strategy, address _token, uint256 parts)
     public view returns(uint256 expected) {
        uint256 _balance = IERC20(_token).balanceOf(_strategy);
        address _want = Strategy(_strategy).want();
        (expected, ) = OneSplitAudit(onesplit).getExpectedReturn(_token, _want, _balance, parts, 0);
     }

    function yearn(address _strategy, address _token, uint256 parts) public 
    {
        require(msg.sender == strategist || msg.sender == governance, "!unauthorised");
        uint256 _before = IERC20(_token).balanceOf(address(this));
        Strategy(_strategy).withdraw(_token);
        uint256 _after = IERC20(_token).balanceOf(address(this));
        if(_after>_before){
            uint256 _amount = _after.sub(_before);
            address _want = Strategy(_strategy).want();
            uint256[] memory _distribution;
            uint256 _expected;
            (_expected, _distribution) = OneSplitAudit(onesplit).getExpectedReturn(_token, _want, _amount, parts, 0);
            OneSplitAudit(onesplit).swap(_token, _want, _amount, _expected, _distribution, 0);
            _after = IERC20(_want).balanceOf(address(this));

            if(_after > _before){
                _amount = _after.sub(_before);
                uint256 reward = _amount.mul(split).div(max);
                earn(_want, _amount.sub(reward));
                IERC20(_want).transfer(rewards, reward);
            }
        }
    }

    function withdraw(address _token, uint256 _amount) public {
        require(msg.sender == vaults[_token], "!vaults");
        Strategy(strategies[_token]).withdraw(_amount);
    }


}
 