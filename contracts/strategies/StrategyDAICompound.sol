// SPDX-License-Identifier: MIT
pragma solidity ^0.8;

import "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import "@openzeppelin/contracts/utils/math/SafeMath.sol";
import "@openzeppelin/contracts/utils/Address.sol";

import "../interfaces/Compound/Comptroller.sol";
import "../interfaces/Compound/cToken.sol";
import "../interfaces/Uniswap/Uni.sol";

import "../interfaces/yearn/IController.sol";

contract StrategyDAICompound {
    using SafeMath for uint256;
    using Address for address;

    address public constant want = address(0x6B175474E89094C44Da98b954EedeAC495271d0F);
    Comptroller public constant compound = Comptroller(0x3d9819210A31b4961b30EF54bE2aeD79B9c9Cd3B);

    address public constant comp = address(0xc00e94Cb662C3520282E6f5717214004A7f26888);
    address public constant cDAI = address(0x5d3a536E4D6DbD6114cc1Ead35777bAB948E3643);
    address public constant uni = address(0x7a250d5630B4cF539739dF2C5dAcb4c659F2488D);
    address public constant weth = address(0xC02aaA39b223FE8D0A0e5C4F27eAD9083C756Cc2);

    uint public performanceFee = 500;
    uint public constant performanceMax = 10000;

    uint public withdrawalFee = 50;
    uint public constant withdrawalMax = 10000;

    address public governance;
    address public controller;
    address public strategist;

    constructor(address _controller){
        governance=msg.sender;
        strategist=msg.sender;
        controller=_controller;
    }

    function getName() external pure returns(string memory) {
        return "StrategyDAICompound";
    }

    function setStrategist(address _strategist) external {
        require(msg.sender==governance, "!governance");
        strategist=_strategist;
    } 

    function setWithdrawalFee(uint256 _withdrawalFee) external {
        require(msg.sender==governance, "!governance");
        withdrawalFee=_withdrawalFee;
    }

    function setPerformanceFee(uint256 _performanceFee) external {
        require(msg.sender==governance, "!governance");
        performanceFee=_performanceFee;
    }

    function deposit() public {
        uint256 _want = IERC20(want).balanceOf(address(this));
        if(_want>0){
            IERC20(want).approve(cDAI, _want);
            cToken(cDAI).mint(_want);
        }
    }

    function withdraw(IERC20 _asset) external returns(uint256 balance) 
    {
        require(msg.sender == controller, "!controller");
        require(want!=address(_asset), "DAI");
        require(cDAI!=address(_asset), "cDAI");
        require(comp!=address(_asset), "comp");
        balance = _asset.balanceOf(address(this));
        _asset.transfer(controller, balance);
    }

    function withdraw(uint256 _amount) external {
        require(msg.sender == controller, "!controller");
        uint256 _balance = IERC20(want).balanceOf(address(this));
        if(_balance < _amount){
            _amount = _withdrawSome(_amount.sub(_balance));
        }

        uint256 _fee = _amount.mul(withdrawalFee).div(withdrawalMax);

        IERC20(want).transfer(IController(controller).rewards(), _fee);
        address _vault = IController(controller).vaults(address(want));
        require(_vault != address(0), "!vault");

        IERC20(want).transfer(_vault, _amount.sub(_fee));
    }

    function withdrawAll() external returns(uint256 balance) {
        require(msg.sender == controller, "!controller");
        _withdrawAll();

        balance = IERC20(want).balanceOf(address(this));

        address _vault = IController(controller).vaults(address(want));
        require(_vault != address(0), "!vault");
        IERC20(want).transfer(_vault, balance);
    }

    function _withdrawAll() internal {
        uint amount = balanceC();
        if(amount>0){
            _withdrawSome(balanceCInToken().sub(1));
        }
    }

    function harvest() public {
        require(msg.sender==strategist || msg.sender==governance, "!authorized");
        compound.claimComp(address(this));
        uint _comp = IERC20(comp).balanceOf(address(this));
        if(_comp>0){
            IERC20(comp).approve(uni, _comp);

            address[] memory path = new address[](3);
            path[0]=comp;
            path[1]=weth;
            path[2]=want;

            Uni(uni).swapExactTokensForTokens(_comp, 0, path, address(this), block.timestamp.add(1800));
        }
        uint _want = IERC20(want).balanceOf(address(this));
        if(_want>0){
            uint256 _fee = _want.mul(performanceFee).div(performanceMax);
            IERC20(want).transfer(IController(controller).rewards(), _fee);
            deposit();
        }
    }

    function _withdrawSome(uint256 _amount) internal returns(uint256) {
        uint256 b = balanceC();
        uint256 bT = balanceCInToken();

        uint256 amount = (b.mul(_amount)).div(bT).add(1);
        uint256 _before = IERC20(want).balanceOf(address(this));
        _withdrawC(amount);
        uint256 _after = IERC20(want).balanceOf(address(this));
        uint256 withdrew = _after.sub(_before);
        return withdrew;
    }

    function _withdrawC(uint256 _amount) internal {
        cToken(cDAI).redeem(_amount);
    }

    function balanceC() public view returns(uint256){
        return IERC20(cDAI).balanceOf(address(this));
    }

    function balanceCInToken() public view returns(uint256){
        uint256 b = balanceC();
        if(b>0){
            b=b.mul(cToken(cDAI).exchangeRateStored()).div(1e18);
        }
        return b;
    }

    function balanceOfWant() public view returns(uint256) {
        return IERC20(want).balanceOf(address(this));
    }

    function balanceOf() public view returns(uint256) {
        return balanceOfWant().add(balanceCInToken());
    }

    function setGovernance(address _governance) external {
        require(msg.sender==governance, "!governance");
        governance = _governance;
    }

    function setController(address _controller) external {
        require(msg.sender==governance, "!governance");
        controller = _controller;
    }


}