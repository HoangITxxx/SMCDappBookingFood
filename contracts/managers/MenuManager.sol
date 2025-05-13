// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

import "../BaseContract.sol";

abstract contract MenuManager is BaseContract {
    // Events
    event MenuItemAdded(uint128 id, uint128 restaurantId, string name);
    event MenuItemUpdated(uint128 id, uint128 restaurantId);
    event MenuItemRemoved(uint128 id, uint128 restaurantId);
    event MenuItemRated(uint128 menuId, uint8 rating);

    // Function declarations (abstract - no implementation)
    function addMenuItem(
        uint128 restaurantId,
        string memory name,
        string memory imageUrl,
        string memory videoUrl,
        uint128 price,
        // uint32 estimatedPrepTime,
        string memory description,
        string memory category
    ) external virtual;

    function updateMenuItem(
        uint128 restaurantId,
        uint128 menuId, 
        string memory name, 
        string memory imageUrl,
        string memory videoUrl,
        uint128 price, 
        bool available,
        // uint32 newEstimatedPrepTime,
        string memory description,
        string memory category
    ) external virtual;

    function removeMenuItem(
        uint128 restaurantId, 
        uint128 menuId
    ) external virtual;

    function getMenuItems(
        uint128 restaurantId, 
        uint128 start, 
        uint128 limit
    ) external view virtual returns (MenuItem[] memory);

    function rateMenuItem(
        uint128 restaurantId, 
        uint128 menuId, 
        uint8 rating
    ) external virtual;

    function getAverageRating(
        uint128 restaurantId, 
        uint128 menuId
    ) external view virtual returns (uint128);
}