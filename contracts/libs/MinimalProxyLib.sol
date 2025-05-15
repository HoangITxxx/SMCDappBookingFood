// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

library MinimalProxyLib {
    function deploy(address implementation) internal returns (address proxy) {
        bytes20 implBytes = bytes20(implementation);
        assembly {
            let clone := mload(0x40)
            mstore(clone, 0x3d602d80600a3d3981f3363d3d373d3d3d363d73)
            mstore(add(clone, 0x14), implBytes)
            mstore(add(clone, 0x28), 0x5af43d82803e903d91602b57fd5bf3)
            proxy := create(0, clone, 0x37)
        }
        require(proxy != address(0), "Deploy failed");
    }
}
