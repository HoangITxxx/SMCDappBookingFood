// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

import "../SMCDappBookingFood.sol";

abstract contract RatingManager is SMCDappBookingFood {
    event EmployeeRated(address indexed employee, address indexed customer, uint128 restaurantId, uint8 rating, string comment);
    event RestaurantRated(uint128 indexed restaurantId, address indexed customer, uint8 rating, string comment);

    function rateEmployee(address employee, uint128 restaurantId, uint8 rating, string memory comment) 
        external 
        onlyStaffOrCustomer 
    {
        require(rating >= 1 && rating <= 5, "Rating must be between 1 and 5");
        require(restaurantOwners[restaurantId] != address(0), "Restaurant does not exist");
        require(roles[employee] == Role.Staff && staffRestaurant[employee] == restaurantId, "Invalid employee");
        
        RatingForEmployee memory newRating = RatingForEmployee({
            customer: msg.sender,
            employee: employee,
            restaurantId: restaurantId,
            rating: rating,
            comment: comment,
            timestamp: uint128(block.timestamp)
        });
        
        employeeRatings[employee].push(newRating);
        emit EmployeeRated(employee, msg.sender, restaurantId, rating, comment);
    }

    function rateRestaurant(uint128 restaurantId, uint8 rating, string memory comment) 
        external 
        onlyAdminOrCustomer 
    {
        require(rating >= 1 && rating <= 5, "Rating must be between 1 and 5");
        require(restaurantOwners[restaurantId] != address(0), "Restaurant does not exist");
        
        RatingForRestaurant memory newRating = RatingForRestaurant({
            customer: msg.sender,
            restaurantId: restaurantId,
            rating: rating,
            comment: comment,
            timestamp: uint128(block.timestamp)
        });
        
        restaurantRatings[restaurantId].push(newRating);
        emit RestaurantRated(restaurantId, msg.sender, rating, comment);
    }

    function getEmployeeRatings(address employee) 
        external 
        view 
        returns (RatingForEmployee[] memory) 
    {
        return employeeRatings[employee];
    }

    function getRestaurantRatings(uint128 restaurantId) 
        external 
        view 
        returns (RatingForRestaurant[] memory) 
    {
        require(restaurantOwners[restaurantId] != address(0), "Restaurant does not exist");
        return restaurantRatings[restaurantId];
    }
}