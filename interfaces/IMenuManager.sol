// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;
import "../structs/FoodTypes.sol";

interface IMenuManager {
    function initialize(address foodAppContract, address owner) external;
    function addMenuItem(uint128 restaurantId, string memory name, string memory menuTitle, string memory imageUrl, uint128 price, string memory description, string memory category, uint128 preparationTime) external;
    function updateMenuItem(UpdateMenuItemParams memory params) external;
    function removeMenuItem(uint128 restaurantId, uint128 menuId) external;
    
    //hàm get
    function getMenuItem(uint128 restaurantId, uint128 menuId) external view returns (MenuItem memory);
    function getMenuItemsByRestaurant(uint128 menuId) external view returns (MenuItem[] memory);
    function getMenuItemIdsByRestaurant(uint128 restaurantId) external view returns (uint128[] memory);
}