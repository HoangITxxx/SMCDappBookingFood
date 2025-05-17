// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

interface IRestaurantManager {
    function initialize(address foodApp, address factoryOwner) external;

    function registerRestaurant(address caller) external returns (uint128);
    function restaurantExists(uint128 restaurantId) external view returns (bool);
    //===== Hàm Get ===================
    function getRestaurantOwner(uint128 restaurantId) external view returns (address);

}