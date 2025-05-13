// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

import "@openzeppelin/contracts/security/ReentrancyGuard.sol";
import "@openzeppelin/contracts/access/Ownable.sol";
import "@openzeppelin/contracts/utils/Address.sol";
import "./managers/MenuManager.sol";
import "./managers/OrderManager.sol";
import "./managers/RatingManager.sol";
import "./managers/RestaurantManager.sol";

contract SMCDappBookingFood is ReentrancyGuard, Ownable, MenuManager, OrderManager, RatingManager, RestaurantManager {
    using Address for address payable;
    
    constructor() Ownable(msg.sender) {
        roles[msg.sender] = Role.Admin;
    }
}