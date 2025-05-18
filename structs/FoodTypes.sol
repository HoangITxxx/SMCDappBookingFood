// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

enum Role { None, Admin, Customer, FOH, BOH } // FOH: Front of House, BOH: Back of House

enum OrderStatus { Placed, Confirmed, Preparing, Ready, Delivered, Completed, Cancelled }

struct MenuItem {
    uint128 id;
    uint128 restaurantId;
    string name;
    string menuTitle;
    string imageUrl;
    uint128 price;
    bool available;
    string description;
    uint128 categoryId;
    uint128 totalRating; 
    uint128 ratingCount; 
    uint128 preparationTime;
}

struct UpdateMenuItemParams {
    uint128 restaurantId;
    uint128 menuId;
    string name;
    string menuTitle;
    string imageUrl;
    uint128 price;
    bool available;
    string description;
    uint128 categoryId;
    uint128 preparationTime;
    uint128 totalRating; 
    uint128 ratingCount;
}

struct Category {
    uint128 id;
    uint128 restaurantId;
    string name;
    string description; 
    bool isActive;
}

struct OrderItemDetail {
    uint128 menuItemId;
    string name;
    uint128 pricePerUnit;
    uint128 quantity;
}

struct Order {
    uint128 id;
    address customer;
    uint128 restaurantId;
    OrderItemDetail[] itemsDetail;
    uint256 totalPrice;
    OrderStatus status;
    uint128 timestamp;
    uint128 preparationTime; 
    uint128 quantity;
    address servingStaff;
    string tableNumber; 
}

struct SuggestedMenuItem {
    uint128 menuItemId;
    string name;
    string imageUrl; 
    uint128 price;    
    uint128 categoryId;
    string categoryName;
    uint256 completedOrderCount;
}

struct Restaurant {
    uint128 id;
    address owner; 
    string name;
    // Thêm các trường khác
}

struct Review {
    uint128 id;
    address customer;
    address staff;
    uint128 restaurantId;
    uint8 rating;
    string comment;
    uint128 timestamp;
}

struct StaffReview {
    uint128 id;
    address customer;
    address staff;
    uint128 restaurantId;
    uint8 rating;
    string comment;
    uint128 timestamp;
}

struct MenuItemReview {
    uint128 id;
    address customer;
    uint128 menuItemId;
    uint128 restaurantId;
    uint8 rating;
    string comment;
    uint128 timestamp;
}

struct UserProfile {
    address userAddress; 
    string name;
    string phoneNumber;
    uint128 CCCD;
    string email; 
    string imageUrl;
    bool isActive; 
    uint128 registrationDate;
}
struct RestaurantStaffMember {
    address staffAddress; 
    Role staffRole;       
    uint128 restaurantId; 
    uint128 assignmentDate;
}
struct StaffMemberDetails {
    address staffAddress;
    string name;
    string phoneNumber;
    uint128 CCCD;
    string email;
    string imageUrl;
    bool isActiveProfile; 
    uint128 registrationDate; 
    uint128 restaurantId;  
    Role staffRoleInRestaurant;
    uint128 assignmentDate; 
}

struct Table {
    uint128 id;
    uint128 restaurantId;
    string tableNumber; 
    bool isActive;
}