// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;
import "../structs/FoodTypes.sol";

interface IOrderManager {
    function initialize(address foodAppContract, address menuManagerAddress, address restaurantManagerAddress, address _tableManagerAddress, address owner) external;
    function placeOrder(address customerEoa, uint128 restaurantId, uint128[] memory itemIds, uint128[] memory quantities, address servingStaffEoa, string memory tableNumber) external payable;
    function cancelOrder(address customerEoa, uint128 orderId) external;
    function completeOrder(address staffEoa, uint128 orderId, uint128 staffRestaurantId) external;
    function updateOrderStatus(address staffEoa, uint128 orderId, OrderStatus newStatus, uint128 staffRestaurantId) external;
    //==== Hàm Get =========================
    function getOrder(uint128 orderId) external view returns (Order memory);
    function getOrdersByCustomer(address customerEoa, uint256 startIndex, uint256 limit) external view returns (Order[] memory ordersAn, uint256 nextStartIndex);
    function getOrderCountByCustomer(address customerEoa) external view returns (uint256);
    function getCompletedOrderItemCount(uint128 _restaurantId, uint128 _menuItemId) external view returns (uint256);
    function getRestaurantCompletedMenuItemIds(uint128 _restaurantId) external view returns (uint128[] memory);

}