// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

abstract contract BaseContract {
    // Định nghĩa tất cả các enum, struct, event chung
    enum Role { Customer, Staff, Admin }
    enum OrderStatus { Placed, Confirmed, Preparing, Ready, Cancelled, Completed }
    
    struct MenuItem {
        uint128 id;
        uint128 restaurantId;
        string name;
        string imageUrl;
        string videoUrl;
        uint128 price;
        // uint32 estimatedPrepTime;
        bool available;
        string description;
        string category;
        uint128 totalRating;
        uint128 ratingCount;
    }
    
    struct Order {
        uint128 id;
        address customer;
        uint128 restaurantId;
        uint128[] itemIds;
        uint128[] quantities;
        // uint32 estimatedCompletionTime;
        uint128 totalPrice;
        OrderStatus status;
        uint128 timestamp;
    }

    struct OrderDetail {
        uint128 menuId;
        uint128 quantity;
        uint128 price;
        string name;
    }

    // Khai báo tất cả các biến state được sử dụng trong modifiers
    mapping(address => Role) public roles;
    mapping(address => uint128) public staffRestaurant;
    mapping(uint128 => address) public restaurantOwners;
    mapping(uint128 => mapping(uint128 => MenuItem)) public menuByRestaurant;
    uint128 public nextOrderId;
    uint128 public nextMenuId;
    
    // Các modifier chung
    modifier onlyAdmin() {
        require(roles[msg.sender] == Role.Admin, "Unauthorized: Admin only");
        _;
    }

    modifier onlyStaffOrAdminOrOwner(uint128 restaurantId) {
        require(
            roles[msg.sender] == Role.Staff && staffRestaurant[msg.sender] == restaurantId ||
            roles[msg.sender] == Role.Admin ||
            restaurantOwners[restaurantId] == msg.sender,
            "Unauthorized: Staff, Admin, or Owner only"
        );
        _;
    }

    modifier onlyAdminOrCustomer() {
        require(
            roles[msg.sender] == Role.Admin || roles[msg.sender] == Role.Customer,
            "Only admin or customer"
        );
        _;
    }

    modifier onlyCustomer() {
        require(roles[msg.sender] == Role.Customer, "Unauthorized: Customer only");
        _;
    }

    modifier validOrderId(uint128 orderId) {
        require(orderId > 0 && orderId < nextOrderId, "Invalid order ID");
        _;
    }

    modifier validMenuItemId(uint128 restaurantId, uint128 menuId) {
        require(menuId > 0 && menuId < nextMenuId, "Invalid menu item ID");
        require(menuByRestaurant[restaurantId][menuId].id != 0, "Menu item does not exist");
        _;
    }

    modifier onlyRestaurantOwner(uint128 restaurantId) {
        require(restaurantOwners[restaurantId] == msg.sender, "Not restaurant owner");
        _;
    }

    modifier onlyStaffOrCustomer() {
        require(
            roles[msg.sender] == Role.Customer || roles[msg.sender] == Role.Staff,
            "Unauthorized: Staff or Customer only"
        );
        _;
    }
}