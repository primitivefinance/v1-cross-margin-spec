// SPDX-License-Identifier: MIT
pragma solidity >=0.6.2;

/**
 * @title   The Primitive House -> Manages collateral, leverages liquidity.
 * @author  Primitive
 */

// Open Zeppelin
import {Ownable} from "@openzeppelin/contracts/access/Ownable.sol";
import {
    ReentrancyGuard
} from "@openzeppelin/contracts/utils/ReentrancyGuard.sol";
/* import {SafeERC20} from "@openzeppelin/contracts/token/ERC20/SafeERC20.sol"; */

// Primitive
import {
    IOption
} from "@primitivefi/contracts/contracts/option/interfaces/IOption.sol";

// Internal
import {Accelerator} from "./Accelerator.sol";
import {ICapitol} from "./interfaces/ICapitol.sol";
import {IERC20} from "./interfaces/IERC20.sol";
import {IVERC20} from "./interfaces/IVERC20.sol";
import {IWETH} from "./interfaces/IWETH.sol";
import {RouterLib} from "./libraries/RouterLib.sol";
import {SafeMath} from "./libraries/SafeMath.sol";
import {VirtualRouter} from "./VirtualRouter.sol";

contract House is Ownable, VirtualRouter, Accelerator {
    /* using SafeERC20 for IERC20; */
    using SafeMath for uint256;

    struct Account {
        mapping(address => uint256) balanceOf;
    }

    // liquidity
    event Leveraged(
        address indexed depositor,
        address indexed optionAddress,
        address indexed pool,
        uint256 quantity
    );
    event Deleveraged(
        address indexed from,
        address indexed optionAddress,
        uint256 liquidity
    );

    event CollateralDeposited(
        address indexed depositor,
        address[] indexed tokens,
        uint256[] amounts
    );
    event CollateralWithdrawn(
        address indexed depositor,
        address[] indexed tokens,
        uint256[] amounts
    );

    ICapitol public capitol;
    Accelerator public accelerator;
    address public CALLER;

    mapping(address => mapping(address => uint256)) public debit;
    mapping(address => mapping(address => uint256)) public credit;

    modifier isEndorsed(address venue_) {
        require(capitol.getIsEndorsed(venue_), "House: NOT_ENDORSED");
        _;
    }

    constructor(
        address weth_,
        address registry_,
        address capitol_
    ) public VirtualRouter(weth_, registry_) {
        capitol = ICapitol(capitol_);
        accelerator = new Accelerator();
    }

    // ==== Balance Sheet Accounting ====

    function addTokens(
        address depositor,
        address[] memory tokens,
        uint256[] memory amounts
    ) public returns (bool) {
        uint256 tokensLength = tokens.length;
        for (uint256 i = 0; i < tokensLength; i++) {
            // Pull tokens from depositor.
            address asset = tokens[i];
            uint256 quantity = amounts[i];
            IERC20(asset).transferFrom(msg.sender, address(this), quantity);
        }
        return _addTokens(depositor, tokens, amounts, false);
    }

    function _addTokens(
        address depositor,
        address[] memory tokens,
        uint256[] memory amounts,
        bool isDebit
    ) internal returns (bool) {
        uint256 tokensLength = tokens.length;
        uint256 amountsLength = amounts.length;
        require(tokensLength == amountsLength, "House: PARAMETER_LENGTH");
        for (uint256 i = 0; i < tokensLength; i++) {
            // Add liquidity to a depositor's respective pool balance.
            address asset = tokens[i];
            uint256 quantity = amounts[i];
            if (isDebit) {
                debit[asset][depositor] = debit[asset][depositor].add(quantity);
            } else {
                credit[asset][depositor] = credit[asset][depositor].add(
                    quantity
                );
            }
        }
        emit CollateralDeposited(depositor, tokens, amounts);
        return true;
    }

    function takeTokensFromUser(address token, uint256 quantity) external {
        address depositor = CALLER; //fix
        IERC20(token).transferFrom(depositor, msg.sender, quantity);
    }

    function removeTokens(
        address withdrawee,
        address[] memory tokens,
        uint256[] memory amounts
    ) public returns (bool) {
        // Remove balances from state.
        _removeTokens(withdrawee, tokens, amounts, true);
        uint256 tokensLength = tokens.length;
        for (uint256 i = 0; i < tokensLength; i++) {
            // Push tokens to withdrawee.
            address asset = tokens[i];
            uint256 quantity = amounts[i];
            IERC20(asset).transfer(withdrawee, quantity);
        }
        return true;
    }

    function _removeTokens(
        address withdrawee,
        address[] memory tokens,
        uint256[] memory amounts,
        bool isDebit
    ) internal returns (bool) {
        uint256 tokensLength = tokens.length;
        uint256 amountsLength = amounts.length;
        require(tokensLength == amountsLength, "House: PARAMETER_LENGTH");
        for (uint256 i = 0; i < tokensLength; i++) {
            // Remove liquidity to a withdrawee's respective pool balance.
            address asset = tokens[i];
            uint256 quantity = amounts[i];
            if (isDebit) {
                debit[asset][withdrawee] = debit[asset][withdrawee].sub(
                    quantity
                );
            } else {
                credit[asset][withdrawee] = credit[asset][withdrawee].sub(
                    quantity
                );
            }
        }
        emit CollateralWithdrawn(withdrawee, tokens, amounts);
        return true;
    }

    function creditBalanceOf(address depositor, address token)
        public
        view
        returns (uint256)
    {
        return credit[token][depositor];
    }

    function debitBalanceOf(address depositor, address token)
        public
        view
        returns (uint256)
    {
        return debit[token][depositor];
    }

    // ==== Execution ====

    // Calls the accelerator intermediary to execute a transaction with a venue on behalf of caller.
    function execute(address venue, bytes calldata params)
        external
        payable
        nonReentrant
        returns (bool)
    {
        CALLER = msg.sender;
        accelerator.executeCall(venue, params);
    }
}