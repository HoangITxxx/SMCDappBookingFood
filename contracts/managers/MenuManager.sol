// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

import "../contract/SMCDappBookingFood.sol";

abstract contract MenuManager is SMCDappBookingFood {
    event MenuItemAdded(uint128 id, uint128 restaurantId, string name);
    event MenuItemUpdated(uint128 id, uint128 restaurantId);
    event MenuItemRemoved(uint128 id, uint128 restaurantId);
    event MenuItemRated(uint128 menuId, uint8 rating);

    function addMenuItem(
        uint128 restaurantId,
        string memory name,
        string memory imageUrl,
        string memory videoUrl,
        uint128 price,
        string memory description,
        string memory category
    ) external onlyStaffOrAdminOrOwner(restaurantId) {
        require(bytes(name).length > 0 && price > 0, "Invalid data");
        require(restaurantOwners[restaurantId] != address(0), "Restaurant does not exist");
        menuByRestaurant[restaurantId][nextMenuId] = MenuItem({
            id: nextMenuId,
            restaurantId: restaurantId,
            name: name,
            imageUrl: imageUrl,
            videoUrl: videoUrl,
            price: price,
            available: true,
            description: description,
            category: category,
            totalRating: 0,
            ratingCount: 0
        });
        emit MenuItemAdded(nextMenuId, restaurantId, name);
        nextMenuId++;
    }

    function updateMenuItem(
        uint128 restaurantId,
        uint128 menuId, 
        string memory name, 
        string memory imageUrl,
        string memory videoUrl,
        uint128 price, 
        bool available,
        string memory description,
        string memory category
    ) external onlyStaffOrAdminOrOwner(restaurantId) validMenuItemId(restaurantId, menuId) {
        require(bytes(name).length > 0 && price > 0, "Invalid data");
        MenuItem storage item = menuByRestaurant[restaurantId][menuId];
        item.name = name;
        item.imageUrl = imageUrl;
        item.videoUrl = videoUrl;
        item.price = price;
        item.available = available;
        item.description = description;
        item.category = category;
        emit MenuItemUpdated(menuId, restaurantId);
    }

    function removeMenuItem(uint128 restaurantId, uint128 menuId) 
        external 
        onlyStaffOrAdminOrOwner(restaurantId) 
        validMenuItemId(restaurantId, menuId) 
    {
        delete menuByRestaurant[restaurantId][menuId];
        emit MenuItemRemoved(menuId, restaurantId);
    }

    function getMenuItems(uint128 restaurantId, uint128 start, uint128 limit) 
        external 
        view 
        returns (MenuItem[] memory) 
    {
        uint128 count = 0;
        for (uint128 i = start + 1; i <= nextMenuId && i <= start + limit; i++) {
            if (menuByRestaurant[restaurantId][i].id != 0) count++;
        }

        MenuItem[] memory items = new MenuItem[](count);
        uint128 index = 0;
        for (uint128 i = start + 1; i <= nextMenuId && i <= start + limit; i++) {
            if (menuByRestaurant[restaurantId][i].id != 0) {
                items[index] = menuByRestaurant[restaurantId][i];
                index++;
            }
        }
        return items;
    }

    function rateMenuItem(uint128 restaurantId, uint128 menuId, uint8 rating) 
        external 
        validMenuItemId(restaurantId, menuId) 
    {
        require(rating >= 1 && rating <= 5, "Invalid rating");
        MenuItem storage item = menuByRestaurant[restaurantId][menuId];
        item.totalRating += rating;
        item.ratingCount += 1;
        emit MenuItemRated(menuId, rating);
    }

    function getAverageRating(uint128 restaurantId, uint128 menuId) 
        public 
        view 
        validMenuItemId(restaurantId, menuId) 
        returns (uint128) 
    {
        MenuItem storage item = menuByRestaurant[restaurantId][menuId];
        if (item.ratingCount == 0) return 0;
        return item.totalRating / item.ratingCount;
    }
}