// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;
import "../structs/FoodTypes.sol"; 

interface IReviewManager {
    function initialize(address foodApp, address restaurantManager, address menuManager, address owner) external;
    function rateRestaurant(address customerEoa, uint128 restaurantId, uint8 rating, string memory comment) external;
    function rateStaff(address customerEoa, address staff, uint128 restaurantId, uint8 rating, string memory comment) external;
    function rateMenuItem(address customerEoa, uint128 restaurantId, uint128 menuItemId, uint8 rating, string memory comment)
        external returns (uint128 newTotalRating, uint128 newRatingCount);
//======= Hàm Get =====================
    function getStaffReviews(address staff) external view returns (StaffReview[] memory);
    function getMenuItemReviews(uint128 menuItemId) external view returns (MenuItemReview[] memory);
    function getAverageStaffRating(address staff) external view returns (uint128 averageRating, uint128 ratingCount);
    function getAverageMenuItemRating(uint128 menuItemId) external view returns (uint128 averageRating, uint128 ratingCount);
}