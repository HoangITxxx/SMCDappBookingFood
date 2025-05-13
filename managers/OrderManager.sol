// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

import "../contract/SMCDappBookingFood.sol";

abstract contract OrderManager is SMCDappBookingFood {
    event OrderPlaced(uint128 id, address customer, uint128 totalPrice);
    event OrderStatusUpdated(uint128 id, OrderStatus status);
    event OrderCancelled(uint128 id, address customer);
    event RefundProcessed(address customer, uint128 totalPrice);
    event OrderCompleted(uint128 orderId, address customer);

    function placeOrder(
        uint128 restaurantId,
        uint128[] memory itemIds,
        uint128[] memory quantities
    ) external payable onlyAdminOrCustomer nonReentrant {
        require(itemIds.length > 0 && itemIds.length == quantities.length, "Invalid input");
        require(restaurantOwners[restaurantId] != address(0), "Restaurant does not exist");
        
        uint128 total = 0;
        OrderDetail[] memory details = new OrderDetail[](itemIds.length);
        for (uint i = 0; i < itemIds.length; i++) {
            MenuItem storage item = menuByRestaurant[restaurantId][itemIds[i]];
            require(item.available, "Item unavailable");
            require(item.restaurantId == restaurantId, "Item does not belong to restaurant");
            total += item.price * quantities[i];
            orderCountDetails[nextOrderId][itemIds[i]] = quantities[i];
            details[i] = OrderDetail({
                menuId: itemIds[i],
                quantity: quantities[i],
                price: item.price,
                name: item.name
            });
        }

        uint128 serviceFee = (total * serviceFeePercentage) / 100;
        uint128 totalAmount = total + serviceFee;
        require(msg.value >= totalAmount, "Insufficient payment");

        if (msg.value > totalAmount) {
            payable(msg.sender).sendValue(msg.value - totalAmount);
        }

        orders[nextOrderId] = Order({
            id: nextOrderId,
            customer: msg.sender,
            restaurantId: restaurantId,
            itemIds: itemIds,
            quantities: quantities,
            totalPrice: total,
            status: OrderStatus.Placed,
            timestamp: uint128(block.timestamp)
        });

        for (uint i = 0; i < details.length; i++){
            orderDetails[nextOrderId].push(details[i]);
        }

        customerOrders[msg.sender].push(nextOrderId);
        pendingWithdrawals[owner()] += serviceFee;

        emit OrderPlaced(nextOrderId, msg.sender, total);
        nextOrderId++;
    }

    function cancelOrder(uint128 orderId) 
        external 
        onlyCustomer 
        nonReentrant 
        validOrderId(orderId) 
    {
        Order storage order = orders[orderId];
        require(order.customer == msg.sender, "Not your order");
        require(
            order.status == OrderStatus.Placed || 
            order.status == OrderStatus.Confirmed,
            "Cannot cancel at this stage"
        );
        
        order.status = OrderStatus.Cancelled;
        payable(msg.sender).sendValue(order.totalPrice);
        
        emit OrderCancelled(orderId, msg.sender);
        emit RefundProcessed(msg.sender, order.totalPrice);
    }

    function completeOrder(uint128 orderId) 
        external 
        onlyAdminOrCustomer 
        nonReentrant 
        validOrderId(orderId) 
    {
        Order storage order = orders[orderId];
        require(order.customer == msg.sender, "Not your order");
        require(order.status == OrderStatus.Ready, "Order not ready");
        
        order.status = OrderStatus.Completed;
        userPoints[msg.sender] += 10;
        emit OrderCompleted(orderId, msg.sender);
        emit OrderStatusUpdated(orderId, OrderStatus.Completed);
    }

    function updateOrderStatus(
        uint128 orderId, 
        OrderStatus status
    ) external onlyStaffOrAdminOrOwner(orders[orderId].restaurantId) nonReentrant validOrderId(orderId) {
        Order storage order = orders[orderId];
        require(order.status != OrderStatus.Cancelled, "Order is cancelled");
        require(order.status != OrderStatus.Completed, "Order already completed");
        
        if (status == OrderStatus.Confirmed) {
            require(order.status == OrderStatus.Placed, "Invalid status transition");
        } else if (status == OrderStatus.Preparing) {
            require(
                order.status == OrderStatus.Placed || 
                order.status == OrderStatus.Confirmed,
                "Invalid status transition"
            );
        } else if (status == OrderStatus.Ready) {
            require(
                order.status == OrderStatus.Preparing ||
                order.status == OrderStatus.Confirmed,
                "Invalid status transition"
            );
        } else {
            revert("Invalid status update");
        }
        
        order.status = status;
        emit OrderStatusUpdated(orderId, status);
    }

    function getMyOrders() external onlyAdminOrCustomer view returns (Order[] memory) {
        uint128[] storage ids = customerOrders[msg.sender];
        Order[] memory result = new Order[](ids.length);
        for (uint i = 0; i < ids.length; i++) {
            result[i] = orders[ids[i]];
        }
        return result;
    }

    function getorderCountDetails(uint128 orderId) 
        external 
        view 
        validOrderId(orderId) 
        returns (
            Order memory order,
            uint128[] memory quantities
        ) 
    {
        order = orders[orderId];
        quantities = new uint128[](order.itemIds.length);
        for (uint i = 0; i < order.itemIds.length; i++) {
            quantities[i] = orderCountDetails[orderId][order.itemIds[i]]; 
        }
        
        return (order, quantities);
    }

    function getOrderDetails(uint128 orderId) 
        external 
        view 
        validOrderId(orderId) 
        returns (
            Order memory order,
            MenuItem[] memory items,
            uint128[] memory quantities
        ) 
    {
        order = orders[orderId];
        OrderDetail[] memory details = orderDetails[orderId];
        
        items = new MenuItem[](details.length);
        quantities = new uint128[](details.length);
        
        for (uint i = 0; i < details.length; i++) {
            items[i] = menuByRestaurant[order.restaurantId][details[i].menuId];
            quantities[i] = details[i].quantity;
        }
        
        return (order, items, quantities);
    }

    function previewTotalAmount(uint128 restaurantId, uint128[] memory itemIds, uint128[] memory quantities) 
        external 
        view 
        returns (uint128 totalAmount) 
    {
        require(itemIds.length == quantities.length, "Length mismatch");
        require(restaurantOwners[restaurantId] != address(0), "Restaurant does not exist");
        uint128 total = 0;

        for (uint i = 0; i < itemIds.length; i++) {
            MenuItem memory item = menuByRestaurant[restaurantId][itemIds[i]];
            require(item.available, "Item unavailable");
            require(item.restaurantId == restaurantId, "Item does not belong to restaurant");
            total += item.price * quantities[i];
        }

        uint128 serviceFee = (total * serviceFeePercentage) / 100;
        return total + serviceFee;
    }

    function getAllOrders(uint128 start, uint128 limit) 
        external 
        view 
        onlyAdmin 
        returns (Order[] memory) 
    {
        uint128 count = nextOrderId - 1 > start ? nextOrderId - 1 - start : 0;
        if (count > limit) count = limit;

        Order[] memory result = new Order[](count);
        for (uint128 i = 0; i < count; i++) {
            result[i] = orders[start + i + 1];
        }
        return result;
    }
}