// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;
import "../structs/FoodTypes.sol";

interface IOrderManager {
    function initialize(address foodAppContract, address menuManagerAddress, address restaurantManagerAddress, address owner) external;
    function placeOrder(address customerEoa, uint128 restaurantId, uint128[] memory itemIds, uint128[] memory quantities) external payable;
    function cancelOrder(address customerEoa, uint128 orderId) external;
    function completeOrder(address staffEoa, uint128 orderId, uint128 staffRestaurantId) external;
    function updateOrderStatus(address staffEoa, uint128 orderId, OrderStatus newStatus, uint128 staffRestaurantId) external;
    function getOrder(uint128 orderId) external view returns (Order memory);
    // Các hàm getAll... nên được bỏ hoặc thiết kế lại (ví dụ: getOrdersByCustomer)
    // function getAllOrders() external view returns (Order[] memory);
    // function getOrderDetailById(uint128 orderId) external view returns (OrderDetail memory); // Gộp vào Order
}