// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

interface IRestaurantManager {
    function initialize(address foodApp, address factoryOwner) external;

    function registerRestaurant(address caller) external returns (uint128);
    function getRestaurantOwner(uint128 restaurantId) external view returns (address);
    function restaurantExists(uint128 restaurantId) external view returns (bool);

}