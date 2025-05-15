// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

import "@openzeppelin/contracts-upgradeable/access/OwnableUpgradeable.sol";
import "@openzeppelin/contracts/utils/ReentrancyGuard.sol";
import "../structs/FoodTypes.sol";
import "../interfaces/IOrderManager.sol";
import "../interfaces/IMenuManager.sol";
import "../interfaces/IRestaurantManager.sol";

contract OrderManager is OwnableUpgradeable, IOrderManager, ReentrancyGuard {
    uint128 public nextOrderId;
    mapping(uint128 => Order) public orders;

    IMenuManager public menuManager;
    IRestaurantManager public restaurantManager;
    address public foodAppContractAddress;
    uint256 public platformFeePercent;

    event OrderPlaced(uint128 indexed orderId, address indexed customerEoa, uint128 indexed restaurantId, uint256 totalPrice);
    event OrderStatusUpdated(uint128 indexed orderId, OrderStatus oldStatus, OrderStatus newStatus);
    event OrderCancelled(uint128 indexed orderId, address indexed customerEoa, uint256 refundAmount);
    event OrderCompleted(uint128 indexed orderId, address indexed restaurantOwner, uint256 amountToRestaurant, uint256 platformFee);
    event PlatformFeeUpdated(uint256 oldFeePercent, uint256 newFeePercent);

    error OrderManager__NotFoodApp();
    error OrderManager__InvalidAddress();
    error OrderManager__InvalidDependencyAddress(string dependencyName);
    error OrderManager__InvalidOrderData();
    error OrderManager__MenuItemNotFound(uint128 restaurantId, uint128 menuItemId);
    error OrderManager__MenuItemNotAvailable(uint128 menuItemId);
    error OrderManager__InsufficientPayment(uint256 required, uint256 sent);
    error OrderManager__OrderNotFound(uint128 orderId);
    error OrderManager__NotOrderOwner(address caller, uint128 orderId);
    error OrderManager__InvalidOrderStatusForAction(OrderStatus currentStatus, string action);
    error OrderManager__InvalidOrderStatusTransition(OrderStatus from, OrderStatus to);
    error OrderManager__TransferFailed();
    error OrderManager__CallerNotRestaurantStaff(address caller, uint128 orderRestaurantId, uint128 staffRestaurantId);
    error OrderManager__PlatformFeeTooHigh(uint256 feePercent);
    error OrderManager__RestaurantOwnerNotFound(uint128 restaurantId);

    modifier onlyFoodAppContract() {
        if (msg.sender != foodAppContractAddress) revert OrderManager__NotFoodApp();
        _;
    }

    function initialize(
        address _foodAppContract,
        address _menuManagerAddress,
        address _restaurantManagerAddress,
        address _factoryOwner
    ) public initializer {
        if (_foodAppContract == address(0)) revert OrderManager__InvalidAddress();
        if (_menuManagerAddress == address(0)) revert OrderManager__InvalidDependencyAddress("MenuManager");
        if (_restaurantManagerAddress == address(0)) revert OrderManager__InvalidDependencyAddress("RestaurantManager");
        __Ownable_init(_factoryOwner);
        foodAppContractAddress = _foodAppContract;
        menuManager = IMenuManager(_menuManagerAddress);
        restaurantManager = IRestaurantManager(_restaurantManagerAddress);
        nextOrderId = 1;
        platformFeePercent = 5;
    }

    function setPlatformFee(uint256 _newFeePercent) external onlyOwner {
        if (_newFeePercent > 50) revert OrderManager__PlatformFeeTooHigh(_newFeePercent);
        emit PlatformFeeUpdated(platformFeePercent, _newFeePercent);
        platformFeePercent = _newFeePercent;
    }

    function placeOrder(
        address customerEoa,
        uint128 restaurantId,
        uint128[] memory itemIds,
        uint128[] memory quantities
    ) external payable override onlyFoodAppContract nonReentrant {
        if (itemIds.length != quantities.length || itemIds.length == 0) revert OrderManager__InvalidOrderData();
        if (customerEoa == address(0)) revert OrderManager__InvalidAddress();

        uint256 calculatedTotalPrice = 0;
        uint128 maxPreparationTime = 0;
        OrderItemDetail[] memory orderItemsMemory = new OrderItemDetail[](itemIds.length); // Mảng memory

        for (uint128 i = 0; i < itemIds.length; i++) {
            MenuItem memory item = menuManager.getMenuItem(restaurantId, itemIds[i]);
            if (item.id == 0) revert OrderManager__MenuItemNotFound(restaurantId, itemIds[i]);
            if (!item.available) revert OrderManager__MenuItemNotAvailable(itemIds[i]);
            if (quantities[i] == 0) revert OrderManager__InvalidOrderData();

            calculatedTotalPrice += uint256(item.price) * quantities[i];
            if (item.preparationTime > maxPreparationTime) {
                maxPreparationTime = item.preparationTime;
            }
            orderItemsMemory[i] = OrderItemDetail({ // Gán vào mảng memory
                menuItemId: item.id,
                name: item.name,
                pricePerUnit: item.price,
                quantity: quantities[i]
            });
        }

        if (msg.value < calculatedTotalPrice) revert OrderManager__InsufficientPayment(calculatedTotalPrice, msg.value);

        if (msg.value > calculatedTotalPrice) {
            (bool success,) = payable(customerEoa).call{value: msg.value - calculatedTotalPrice}("");
            if (!success) revert OrderManager__TransferFailed();
        }

        uint128 currentOrderId = nextOrderId;

        // Tạo Order struct trong storage và gán các trường không phải mảng struct trước
        Order storage newOrder = orders[currentOrderId]; // Lấy tham chiếu storage
        newOrder.id = currentOrderId;
        newOrder.customer = customerEoa;
        newOrder.restaurantId = restaurantId;
        newOrder.totalPrice = calculatedTotalPrice;
        newOrder.status = OrderStatus.Placed;
        newOrder.timestamp = uint128(block.timestamp);
        newOrder.preparationTime = maxPreparationTime;
        // newOrder.itemsDetail sẽ là một mảng rỗng trong storage tại thời điểm này

        for (uint i = 0; i < orderItemsMemory.length; i++) {
            newOrder.itemsDetail.push(orderItemsMemory[i]); // Push từng OrderItemDetail vào itemsDetail của newOrder
        }

        emit OrderPlaced(currentOrderId, customerEoa, restaurantId, calculatedTotalPrice);
        nextOrderId++;
    }

    // ... (các hàm còn lại: cancelOrder, completeOrder, updateOrderStatus, getOrder) ...
    // Đảm bảo các hàm này cũng xử lý `orders[orderId]` một cách cẩn thận nếu chúng
    // cần tạo hoặc sửa đổi các mảng struct phức tạp.
    // Tuy nhiên, các hàm còn lại chủ yếu là đọc hoặc cập nhật các trường đơn giản,
    // nên ít có khả năng gặp lỗi tương tự.

    function cancelOrder(address customerEoa, uint128 orderId) external override onlyFoodAppContract nonReentrant {
        Order storage orderToCancel = orders[orderId];
        if (orderToCancel.id == 0) revert OrderManager__OrderNotFound(orderId);
        if (orderToCancel.customer != customerEoa) revert OrderManager__NotOrderOwner(customerEoa, orderId);

        if (orderToCancel.status != OrderStatus.Placed && orderToCancel.status != OrderStatus.Confirmed) {
            revert OrderManager__InvalidOrderStatusForAction(orderToCancel.status, "cancel");
        }

        OrderStatus oldStatus = orderToCancel.status;
        orderToCancel.status = OrderStatus.Cancelled;

        if (orderToCancel.totalPrice > 0) {
            (bool success,) = payable(orderToCancel.customer).call{value: orderToCancel.totalPrice}("");
            if (!success) revert OrderManager__TransferFailed();
        }

        emit OrderCancelled(orderId, customerEoa, orderToCancel.totalPrice);
        emit OrderStatusUpdated(orderId, oldStatus, OrderStatus.Cancelled);
    }

    function completeOrder(address staffEoa, uint128 orderId, uint128 staffRestaurantId) external override onlyFoodAppContract nonReentrant {
        Order storage orderToComplete = orders[orderId];
        if (orderToComplete.id == 0) revert OrderManager__OrderNotFound(orderId);
        if (orderToComplete.restaurantId != staffRestaurantId) {
            revert OrderManager__CallerNotRestaurantStaff(staffEoa, orderToComplete.restaurantId, staffRestaurantId);
        }

        if (orderToComplete.status != OrderStatus.Ready && orderToComplete.status != OrderStatus.Delivered) {
            revert OrderManager__InvalidOrderStatusForAction(orderToComplete.status, "complete");
        }

        OrderStatus oldStatus = orderToComplete.status;
        orderToComplete.status = OrderStatus.Completed;

        address restaurantOwnerEoa = restaurantManager.getRestaurantOwner(orderToComplete.restaurantId);
        if (restaurantOwnerEoa == address(0)) revert OrderManager__RestaurantOwnerNotFound(orderToComplete.restaurantId);

        uint256 amountToRestaurant = orderToComplete.totalPrice;
        uint256 feeAmount = 0;
        if (platformFeePercent > 0 && platformFeePercent <= 100) {
             feeAmount = (orderToComplete.totalPrice * platformFeePercent) / 100;
             amountToRestaurant = orderToComplete.totalPrice - feeAmount;
        }

        if (amountToRestaurant > 0) {
            (bool success,) = payable(restaurantOwnerEoa).call{value: amountToRestaurant}("");
            if (!success) revert OrderManager__TransferFailed();
        }

        emit OrderCompleted(orderId, restaurantOwnerEoa, amountToRestaurant, feeAmount);
        emit OrderStatusUpdated(orderId, oldStatus, OrderStatus.Completed);
    }

    function updateOrderStatus(address staffEoa, uint128 orderId, OrderStatus newStatus, uint128 staffRestaurantId) external override onlyFoodAppContract {
        Order storage orderToUpdate = orders[orderId];
        if (orderToUpdate.id == 0) revert OrderManager__OrderNotFound(orderId);
        if (orderToUpdate.restaurantId != staffRestaurantId) {
            revert OrderManager__CallerNotRestaurantStaff(staffEoa, orderToUpdate.restaurantId, staffRestaurantId);
        }

        if (orderToUpdate.status == OrderStatus.Completed || orderToUpdate.status == OrderStatus.Cancelled) {
            revert OrderManager__InvalidOrderStatusForAction(orderToUpdate.status, "update (already final)");
        }
        if (newStatus == OrderStatus.Placed) {
            revert OrderManager__InvalidOrderStatusTransition(orderToUpdate.status, newStatus);
        }

        OrderStatus oldStatus = orderToUpdate.status;
        orderToUpdate.status = newStatus;
        emit OrderStatusUpdated(orderId, oldStatus, newStatus);
    }

    function getOrder(uint128 orderId) external view override returns (Order memory) {
        Order memory order = orders[orderId];
        if (order.id == 0) revert OrderManager__OrderNotFound(orderId);
        return order;
    }
}