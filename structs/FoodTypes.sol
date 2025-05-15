// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

enum Role { None, Admin, Customer, FOH, BOH } // FOH: Front of House, BOH: Back of House

enum OrderStatus { Placed, Confirmed, Preparing, Ready, Delivered, Completed, Cancelled }

struct MenuItem {
    uint128 id;
    uint128 restaurantId;
    string name;
    string menuTitle;
    uint128 price;
    bool available;
    string description;
    string category;
    uint128 totalRating; 
    uint128 ratingCount; 
    uint128 preparationTime;
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
    uint128 restaurantId;
    uint8 rating;
    string comment;
    uint128 timestamp;
}