// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

import "@openzeppelin/contracts-upgradeable/access/OwnableUpgradeable.sol";
import "../structs/FoodTypes.sol";
import "../interfaces/IReviewManager.sol";
import "../interfaces/IRestaurantManager.sol";
import "../interfaces/IMenuManager.sol"; 

contract ReviewManager is OwnableUpgradeable, IReviewManager {
    uint128 public nextReviewId;
    mapping(uint128 => Review) public reviews;
    mapping(uint128 => uint128[]) public reviewsByRestaurant; 

    IMenuManager public menuManager;

    address public foodAppContractAddress;
    IRestaurantManager public restaurantManager;

    event RestaurantRated(uint128 indexed reviewId, address indexed customer, uint128 indexed restaurantId, uint8 rating);

    error ReviewManager__NotFoodApp();
    error ReviewManager__InvalidAddress();
    error ReviewManager__RestaurantNotFound();
    error ReviewManager__InvalidRating();

    modifier onlyFoodAppContract() {
        if (msg.sender != foodAppContractAddress) revert ReviewManager__NotFoodApp();
        _;
    }

    function initialize(address _foodAppContract, address _restaurantManagerAddress, address _owner) public initializer {
        if (_foodAppContract == address(0) || _restaurantManagerAddress == address(0)) revert ReviewManager__InvalidAddress();
        __Ownable_init(_owner);
        foodAppContractAddress = _foodAppContract;
        restaurantManager = IRestaurantManager(_restaurantManagerAddress);
        nextReviewId = 1;
    }

    function rateRestaurant(address customerEoa, uint128 restaurantId, uint8 rating, string memory comment) external override onlyFoodAppContract {
        if (!restaurantManager.restaurantExists(restaurantId)) revert ReviewManager__RestaurantNotFound();
        if (rating < 1 || rating > 5) revert ReviewManager__InvalidRating();

        uint128 reviewId = nextReviewId++;
        reviews[reviewId] = Review({
            id: reviewId,
            customer: customerEoa,
            restaurantId: restaurantId,
            rating: rating,
            comment: comment,
            timestamp: uint128(block.timestamp)
        });
        reviewsByRestaurant[restaurantId].push(reviewId);

        // Tùy chọn: Cập nhật tổng rating và số lượt rating trong MenuItem
        // Điều này tạo sự phụ thuộc vào MenuManager và có thể làm phức tạp.
        // Một giải pháp khác là tính toán rating trung bình off-chain hoặc khi query.
        // Ví dụ (nếu quyết định cập nhật):
        // MenuItem storage item = menuManager.getMenuItem(...); // Cần cách lấy MenuItem hoặc MenuManager tự xử lý
        // item.totalRating += rating;
        // item.ratingCount++;

        emit RestaurantRated(reviewId, customerEoa, restaurantId, rating);
    }
}