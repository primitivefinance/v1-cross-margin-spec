pragma solidity ^0.7.1;

import {IERC1155} from "@openzeppelin/contracts/token/ERC1155/IERC1155.sol";

interface IMultiToken is IERC1155 {
    function mint(address token, uint256 amount) external;

    function burn(address token, uint256 amount) external;

    // ===== Options =====
    function mintOption(
        bytes32 oid,
        address long,
        address short,
        uint256 amount
    ) external;

    function mintBatch(address[] calldata tokens, uint256[] calldata amounts)
        external
        returns (uint256[] calldata, uint256[] calldata);

    function burnOption(
        bytes32 oid,
        address long,
        address short,
        uint256 amount
    ) external;

    function balanceOfERC20(address token, address user)
        external
        view
        returns (uint256);

    function getUnderlyingToken(uint256 id) external view returns (address);
}
