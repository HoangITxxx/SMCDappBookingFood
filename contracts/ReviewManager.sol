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
    mapping(uint128 => StaffReview) public staffReviews; 
    mapping(uint128 => MenuItemReview) public menuItemReviews; 
    mapping(uint128 => uint128[]) public reviewsByRestaurant;
    mapping(address => uint128[]) public reviewsByStaff; 
    mapping(uint128 => uint128[]) public reviewsByMenuItem;

    IMenuManager public menuManager;

    address public foodAppContractAddress;
    IRestaurantManager public restaurantManager;

    event RestaurantRated(uint128 indexed reviewId, address indexed customer, uint128 indexed restaurantId, uint8 rating);
    event StaffRated(uint128 indexed reviewId, address indexed customer, address indexed staff, uint128 restaurantId, uint8 rating);
    event MenuItemRated(uint128 indexed reviewId, address indexed customer, uint128 indexed menuItemId, uint128 restaurantId, uint8 rating);

    error ReviewManager__NotFoodApp();
    error ReviewManager__InvalidAddress();
    error ReviewManager__RestaurantNotFound();
    error ReviewManager__MenuItemNotFound();
    error ReviewManager__InvalidRating();

    modifier onlyFoodAppContract() {
        if (msg.sender != foodAppContractAddress) revert ReviewManager__NotFoodApp();
        _;
    }

    function initialize(address _foodAppContract, address _restaurantManagerAddress, address _menuManagerAddress, address _owner) 
        public initializer {
        if (_foodAppContract == address(0) || _restaurantManagerAddress == address(0) || _menuManagerAddress == address(0)) 
            revert ReviewManager__InvalidAddress();
        __Ownable_init(_owner);
        foodAppContractAddress = _foodAppContract;
        restaurantManager = IRestaurantManager(_restaurantManagerAddress);
        menuManager = IMenuManager(_menuManagerAddress);
        nextReviewId = 1;
    }

    function rateRestaurant(address customerEoa, uint128 restaurantId, uint8 rating, string memory comment) 
        external override onlyFoodAppContract {
        if (!restaurantManager.restaurantExists(restaurantId)) revert ReviewManager__RestaurantNotFound();
        if (rating < 1 || rating > 5) revert ReviewManager__InvalidRating();

        uint128 reviewId = nextReviewId++;
        reviews[reviewId] = Review({
            id: reviewId,
            customer: customerEoa,
            staff: address(0),
            restaurantId: restaurantId,
            rating: rating,
            comment: comment,
            timestamp: uint128(block.timestamp)
        });
        reviewsByRestaurant[restaurantId].push(reviewId);

        emit RestaurantRated(reviewId, customerEoa, restaurantId, rating);
    }

    function rateStaff(address customerEoa, address staff, uint128 restaurantId, uint8 rating, string memory comment) 
        external override onlyFoodAppContract {
        if (!restaurantManager.restaurantExists(restaurantId)) revert ReviewManager__RestaurantNotFound();
        if (staff == address(0)) revert ReviewManager__InvalidAddress();
        if (rating < 1 || rating > 5) revert ReviewManager__InvalidRating();

        uint128 reviewId = nextReviewId++;
        staffReviews[reviewId] = StaffReview({
            id: reviewId,
            customer: customerEoa,
            staff: staff,
            restaurantId: restaurantId,
            rating: rating,
            comment: comment,
            timestamp: uint128(block.timestamp)
        });
        reviewsByStaff[staff].push(reviewId);
        reviewsByRestaurant[restaurantId].push(reviewId);

        emit StaffRated(reviewId, customerEoa, staff, restaurantId, rating);
    }

    function rateMenuItem(address customerEoa, uint128 restaurantId, uint128 menuItemId, uint8 rating, string memory comment)
        external override onlyFoodAppContract returns (uint128 newTotalRating, uint128 newRatingCount) { 
        if (!restaurantManager.restaurantExists(restaurantId)) revert ReviewManager__RestaurantNotFound();
        if (rating < 1 || rating > 5) revert ReviewManager__InvalidRating();

        MenuItem memory item; 
        try menuManager.getMenuItem(restaurantId, menuItemId) returns (MenuItem memory fetchedItem) {
            item = fetchedItem; 
        } catch {
            revert ReviewManager__MenuItemNotFound();
        }

        if(item.id == 0) revert ReviewManager__MenuItemNotFound();


        uint128 reviewId = nextReviewId++;
        menuItemReviews[reviewId] = MenuItemReview({
            id: reviewId,
            customer: customerEoa,
            menuItemId: menuItemId,
            restaurantId: restaurantId,
            rating: rating,
            comment: comment,
            timestamp: uint128(block.timestamp)
        });
        reviewsByMenuItem[menuItemId].push(reviewId);
        reviewsByRestaurant[restaurantId].push(reviewId);

        emit MenuItemRated(reviewId, customerEoa, menuItemId, restaurantId, rating);

        newTotalRating = item.totalRating + rating;
        newRatingCount = item.ratingCount + 1;
        return (newTotalRating, newRatingCount);
    }

//========== Hàm View =======================================

    function getStaffReviews(address staff) external view override returns (StaffReview[] memory) {
        uint128[] memory reviewIds = reviewsByStaff[staff];
        StaffReview[] memory result = new StaffReview[](reviewIds.length);
        for (uint i = 0; i < reviewIds.length; i++) {
            result[i] = staffReviews[reviewIds[i]];
        }
        return result;
    }

    function getMenuItemReviews(uint128 menuItemId) external view override returns (MenuItemReview[] memory) {
        uint128[] memory reviewIds = reviewsByMenuItem[menuItemId];
        MenuItemReview[] memory result = new MenuItemReview[](reviewIds.length);
        for (uint i = 0; i < reviewIds.length; i++) {
            result[i] = menuItemReviews[reviewIds[i]];
        }
        return result;
    }

    function getAverageStaffRating(address staff) external view override returns (uint128 averageRating, uint128 ratingCount) {
        uint128[] memory reviewIds = reviewsByStaff[staff];
        if (reviewIds.length == 0) return (0, 0);

        uint256 totalRating = 0;
        for (uint i = 0; i < reviewIds.length; i++) {
            totalRating += staffReviews[reviewIds[i]].rating;
        }
        averageRating = uint128(totalRating / reviewIds.length);
        ratingCount = uint128(reviewIds.length);
    }

    function getAverageMenuItemRating(uint128 menuItemId) external view override returns (uint128 averageRating, uint128 ratingCount) {
        try menuManager.getMenuItem(0, menuItemId) returns (MenuItem memory item) {
            if (item.ratingCount == 0) return (0, 0);
            averageRating = uint128(item.totalRating / item.ratingCount);
            ratingCount = item.ratingCount;
        } catch {
            return (0, 0);
        }
    }
}