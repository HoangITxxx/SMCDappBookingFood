// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;
import "../structs/FoodTypes.sol";

interface IMenuManager {
    function initialize(address foodAppContract, address owner) external;
    function addMenuItem(uint128 restaurantId, string memory name, string memory menuTitle, uint128 price, string memory description, string memory category, uint128 preparationTime) external;
    function updateMenuItem(uint128 restaurantId, uint128 menuId, string memory name, string memory menuTitle, uint128 price, bool available, string memory description, string memory category, uint128 preparationTime) external;
    function removeMenuItem(uint128 restaurantId, uint128 menuId) external;
    function getMenuItem(uint128 restaurantId, uint128 menuId) external view returns (MenuItem memory);
}