// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

import "../contract/SMCDappBookingFood.sol";

abstract contract RestaurantManager is SMCDappBookingFood {
    event RestaurantRegistered(uint128 restaurantId, address owner);
    event StaffAssigned(address staff, uint128 restaurantId); 
    event RoleAssigned(address user, Role role);
    event ServiceFeeUpdated(uint8 newPercentage);
    event PaymentReleased(address recipient, uint128 amount);

    function registerRestaurant() external returns (uint128) {
        uint128 restaurantId = nextRestaurantId;
        restaurantOwners[restaurantId] = msg.sender;
        ownerRestaurants[msg.sender].push(restaurantId);
        emit RestaurantRegistered(restaurantId, msg.sender);
        nextRestaurantId++;
        return restaurantId;
    }

    function assignStaff(address staff, uint128 restaurantId) 
        external 
        onlyRestaurantOwner(restaurantId) 
    {
        require(staff != address(0), "Invalid address");
        require(restaurantOwners[restaurantId] != address(0), "Restaurant does not exist");
        roles[staff] = Role.Staff;
        staffRestaurant[staff] = restaurantId;
        emit StaffAssigned(staff, restaurantId);
    }

    function assignRole(address user, Role role) external onlyAdmin {
        require(user != address(0), "Invalid address");
        roles[user] = role;
        // Clear staffRestaurant if role is not Staff
        if (role != Role.Staff) {
            delete staffRestaurant[user];
        }
        emit RoleAssigned(user, role);
    }

    function setServiceFeePercentage(uint8 percentage) external onlyAdmin {
        require(percentage <= MAX_SERVICE_FEE, "Service fee too high");
        serviceFeePercentage = percentage;
        emit ServiceFeeUpdated(percentage);
    }

    function withdrawServiceFees() external onlyAdmin nonReentrant {
        uint128 balance = pendingWithdrawals[owner()];
        require(balance > 0, "No funds available");
        
        pendingWithdrawals[owner()] = 0;
        payable(owner()).sendValue(balance);
        
        emit PaymentReleased(owner(), balance);
    }
}