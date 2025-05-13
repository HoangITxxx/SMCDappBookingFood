// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

import "../BaseContract.sol";

abstract contract RatingManager is BaseContract {

    // Định nghĩa struct trong abstract contract
    struct RatingForEmployee {
        address customer;
        address employee;
        uint128 restaurantId;
        uint8 rating;
        string comment;
        uint128 timestamp;
    }

    struct RatingForRestaurant {
        address customer;
        uint128 restaurantId;
        uint8 rating;
        string comment;
        uint128 timestamp;
    }
    // Events
    event EmployeeRated(address indexed employee, address indexed customer, uint128 restaurantId, uint8 rating, string comment);
    event RestaurantRated(uint128 indexed restaurantId, address indexed customer, uint8 rating, string comment);

    // Function declarations (abstract - no implementation)
    function rateEmployee(
        address employee, 
        uint128 restaurantId, 
        uint8 rating, 
        string memory comment
    ) external virtual;

    function rateRestaurant(
        uint128 restaurantId, 
        uint8 rating, 
        string memory comment
    ) external virtual;

    function getEmployeeRatings(
        address employee
    ) external view virtual returns (RatingForEmployee[] memory);

    function getRestaurantRatings(
        uint128 restaurantId
    ) external view virtual returns (RatingForRestaurant[] memory);
}