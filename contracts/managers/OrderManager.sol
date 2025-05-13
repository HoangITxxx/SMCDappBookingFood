// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

import "../BaseContract.sol";

abstract contract OrderManager is BaseContract {
    event OrderPlaced(uint128 id, address customer, uint128 totalPrice);
    event OrderStatusUpdated(uint128 id, OrderStatus status);
    event OrderCancelled(uint128 id, address customer);
    event RefundProcessed(address customer, uint128 totalPrice);
    event OrderCompleted(uint128 orderId, address customer);

    function placeOrder(
        uint128 restaurantId,
        uint128[] memory itemIds,
        uint128[] memory quantities
    ) external payable virtual;

    function cancelOrder(uint128 orderId) external virtual;

    function completeOrder(uint128 orderId) external virtual;

    function updateOrderStatus(
        uint128 orderId, 
        OrderStatus status
    ) external virtual;

    function getMyOrders() external view virtual returns (Order[] memory);

    // function getorderCountDetails(uint128 orderId) 
    //     external 
    //     view 
    //     virtual
    //     returns (
    //         Order memory order,
    //         uint128[] memory quantities
    //     );

    function getOrderDetails(uint128 orderId) 
        external 
        view 
        virtual
        returns (
            Order memory order,
            MenuItem[] memory items,
            uint128[] memory quantities
        );

    // function previewTotalAmount(
    //     uint128 restaurantId, 
    //     uint128[] memory itemIds, 
    //     uint128[] memory quantities
    // ) external view virtual returns (uint128 totalAmount);

    function getAllOrders(uint128 start, uint128 limit) 
        external 
        view 
        virtual
        returns (Order[] memory);
}