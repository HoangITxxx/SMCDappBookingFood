// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;
// import "../structs/FoodTypes.sol"; // Không cần nếu ReviewManager không trả về Review struct trực tiếp trong interface

interface IReviewManager {
    function initialize(address foodAppContract, address restaurantManagerAddress, address owner) external;
    function rateRestaurant(address customerEoa, uint128 restaurantId, uint8 rating, string memory comment) external;
    // function getReviewsForRestaurant(uint128 restaurantId) external view returns (Review[] memory); // Cân nhắc gas
    // function getAverageRating(uint128 restaurantId) external view returns (uint8 average, uint128 count);
}