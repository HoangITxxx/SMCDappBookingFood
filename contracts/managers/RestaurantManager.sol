// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

import "../BaseContract.sol";

abstract contract RestaurantManager is BaseContract {
    // Events
    event RestaurantRegistered(uint128 restaurantId, address owner);
    event StaffAssigned(address staff, uint128 restaurantId);
    event RoleAssigned(address user, Role role);
    event ServiceFeeUpdated(uint8 newPercentage);
    event PaymentReleased(address recipient, uint128 amount);

    // Function declarations (abstract - no implementation)
    function registerRestaurant() external virtual returns (uint128);
    
    function assignStaff(
        address staff, 
        uint128 restaurantId
    ) external virtual;
    
    // function assignRole(
    //     address user, 
    //     Role role
    // ) external virtual;
    
    function setServiceFeePercentage(
        uint8 percentage
    ) external virtual;
    
    // function withdrawServiceFees() external virtual;
}