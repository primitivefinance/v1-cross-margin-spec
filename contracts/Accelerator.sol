pragma solidity >=0.6.2;

/**
 * @title Primitive Accelerator -> Execution contract between House and Venues.
 */

contract Accelerator {
    function executeCall(address target, bytes calldata params)
        external
        payable
    {
        (bool success, bytes memory returnData) =
            target.call{value: msg.value}(params);
        require(success, "Accelerator: EXECUTION_FAIL");
    }
}
