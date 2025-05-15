// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

import "@openzeppelin/contracts-upgradeable/security/ReentrancyGuardUpgradeable.sol";
import "@openzeppelin/contracts-upgradeable/access/OwnableUpgradeable.sol";
import "../access/RoleAccess.sol"; 
import "./FoodAppFactory.sol";
import "../interfaces/IMenuManager.sol";
import "../interfaces/IOrderManager.sol";
import "../interfaces/IReviewManager.sol";
import "../interfaces/IRestaurantManager.sol";
import "../structs/FoodTypes.sol";

contract FoodApp is OwnableUpgradeable, ReentrancyGuardUpgradeable, RoleAccess {
    FoodAppFactory public factory;
    address public restaurantManager; 
    address public menuManager;       
    address public orderManager;        
    address public reviewManager;       
    event ManagerDeployed(string managerType, address managerAddress);
    // Thêm các event cho các hành động của FoodApp
    event RestaurantRegisteredInApp(uint128 indexed restaurantId, address indexed owner);
    event RoleGrantedInApp(address indexed account, Role indexed role);
    event StaffAssignedInApp(address indexed staff, uint128 indexed restaurantId, Role staffRole);


    error FoodApp__InvalidFactoryAddress();
    error FoodApp__ManagerAlreadyDeployed(string managerType);
    error FoodApp__ManagerNotSet(string managerType);
    error FoodApp__DependencyNotDeployed(string managerType);
    error FoodApp__InvalidRestaurantId();
    error FoodApp__NotAuthorized(); 
    error FoodApp__NotRestaurantStaff();
    error FoodApp__ActionNotAllowedForRole();


    // --- Initializer and Manager Deployment ---
    function initialize(address _appAdmin, address _factoryAddress) public initializer {
        __Ownable_init(_appAdmin); 
        __ReentrancyGuard_init();
        initializeRoles(_appAdmin); 

        if (_factoryAddress == address(0)) revert FoodApp__InvalidFactoryAddress();
        factory = FoodAppFactory(_factoryAddress);
    }

    function deployRestaurantManager() external onlyOwner { 
        if (restaurantManager != address(0)) revert FoodApp__ManagerAlreadyDeployed("RestaurantManager");
        restaurantManager = factory.deployManager("RestaurantManager");
        emit ManagerDeployed("RestaurantManager", restaurantManager);
    }

    function deployMenuManager() external onlyOwner {
        if (menuManager != address(0)) revert FoodApp__ManagerAlreadyDeployed("MenuManager");
        menuManager = factory.deployManager("MenuManager");
        emit ManagerDeployed("MenuManager", menuManager);
    }

    function deployOrderManager() external onlyOwner {
        if (orderManager != address(0)) revert FoodApp__ManagerAlreadyDeployed("OrderManager");
        if (menuManager == address(0)) revert FoodApp__DependencyNotDeployed("MenuManager for OrderManager");
        if (restaurantManager == address(0)) revert FoodApp__DependencyNotDeployed("RestaurantManager for OrderManager");
        orderManager = factory.deployManager("OrderManager");
        emit ManagerDeployed("OrderManager", orderManager);
    }

    function deployReviewManager() external onlyOwner {
        if (reviewManager != address(0)) revert FoodApp__ManagerAlreadyDeployed("ReviewManager");
        if (restaurantManager == address(0)) revert FoodApp__DependencyNotDeployed("RestaurantManager for ReviewManager");
        reviewManager = factory.deployManager("ReviewManager");
        emit ManagerDeployed("ReviewManager", reviewManager);
    }

    // --- Role Management (by FoodApp Admin) ---
    // Hàm onlyAdmin được kế thừa từ RoleAccess và kiểm tra roles[msg.sender] == Role.Admin
    function grantAppRole(address account, Role role) external onlyAdmin {
        super.grantRole(account, role); 
        emit RoleGrantedInApp(account, role);
    }

    function revokeAppRole(address account) external onlyAdmin {
        super.revokeRole(account); 
    }

    function assignStaffMemberToRestaurant(address staffAccount, uint128 restaurantId, Role staffRole) external onlyAdmin {
        if (restaurantManager == address(0)) revert FoodApp__ManagerNotSet("RestaurantManager");
        if (!IRestaurantManager(restaurantManager).restaurantExists(restaurantId)) revert FoodApp__InvalidRestaurantId();
        // Đảm bảo staffRole là FOH hoặc BOH
        if (staffRole != Role.FOH && staffRole != Role.BOH) revert FoodApp__ActionNotAllowedForRole();

        super.assignStaffToRestaurant(staffAccount, restaurantId, staffRole);
        emit StaffAssignedInApp(staffAccount, restaurantId, staffRole);
    }

    function removeStaffMemberFromRestaurant(address staffAccount, uint128 restaurantId) external onlyAdmin {
        if (restaurantManager == address(0)) revert FoodApp__ManagerNotSet("RestaurantManager");
        if (!IRestaurantManager(restaurantManager).restaurantExists(restaurantId)) revert FoodApp__InvalidRestaurantId();
        super.removeStaffFromRestaurant(staffAccount, restaurantId); 
    }

    // --- Restaurant Management (by FoodApp Admin) ---
    function registerNewRestaurant(address restaurantActualOwner) external onlyAdmin returns (uint128) {
        if (restaurantManager == address(0)) revert FoodApp__ManagerNotSet("RestaurantManager");
        uint128 restaurantId = IRestaurantManager(restaurantManager).registerRestaurant(restaurantActualOwner);
        emit RestaurantRegisteredInApp(restaurantId, restaurantActualOwner);
        return restaurantId;
    }

    // --- Menu Management ---
    // Modifier này kiểm tra xem msg.sender có phải là Admin của FoodApp,
    // HOẶC là chủ sở hữu của nhà hàng, HOẶC là nhân viên được gán cho nhà hàng đó.
    modifier onlyRestaurantPrivileged(uint128 _restaurantId) {
        bool isAppAdmin = roles[msg.sender] == Role.Admin;
        bool isRestaurantActualOwner = false;
        if (restaurantManager != address(0) && IRestaurantManager(restaurantManager).restaurantExists(_restaurantId)) {
            isRestaurantActualOwner = (IRestaurantManager(restaurantManager).getRestaurantOwner(_restaurantId) == msg.sender);
        }
        bool isRestaurantStaff = _isStaffOfRestaurant(msg.sender, _restaurantId);

        if (!isAppAdmin && !isRestaurantActualOwner && !isRestaurantStaff) {
            revert FoodApp__NotAuthorized();
        }
        _;
    }

    function addMenuItemToRestaurant(
        uint128 restaurantId,
        string memory name,
        string memory menuTitle,
        uint128 price,
        string memory description,
        string memory category,
        uint128 preparationTime
    ) external onlyRestaurantPrivileged(restaurantId) {
        if (menuManager == address(0)) revert FoodApp__ManagerNotSet("MenuManager");
        if (restaurantManager == address(0) || !IRestaurantManager(restaurantManager).restaurantExists(restaurantId)) {
             revert FoodApp__InvalidRestaurantId();
        }
        IMenuManager(menuManager).addMenuItem(restaurantId, name, menuTitle, price, description, category, preparationTime);
    }

    function updateMenuItemDetails(
        uint128 restaurantId,
        uint128 menuId,
        string memory name,
        string memory menuTitle,
        uint128 price,
        bool available,
        string memory description,
        string memory category,
        uint128 preparationTime
    ) external onlyRestaurantPrivileged(restaurantId) {
        if (menuManager == address(0)) revert FoodApp__ManagerNotSet("MenuManager");
        if (restaurantManager == address(0) || !IRestaurantManager(restaurantManager).restaurantExists(restaurantId)) {
             revert FoodApp__InvalidRestaurantId();
        }
        IMenuManager(menuManager).updateMenuItem(restaurantId, menuId, name, menuTitle, price, available, description, category, preparationTime);
    }

    function removeMenuItemFromRestaurant(uint128 restaurantId, uint128 menuId) external onlyRestaurantPrivileged(restaurantId) {
        if (menuManager == address(0)) revert FoodApp__ManagerNotSet("MenuManager");
        if (restaurantManager == address(0) || !IRestaurantManager(restaurantManager).restaurantExists(restaurantId)) {
             revert FoodApp__InvalidRestaurantId();
        }
        IMenuManager(menuManager).removeMenuItem(restaurantId, menuId);
    }

    // --- Order Management ---
    // onlyCustomer được kế thừa từ RoleAccess
    function placeCustomerOrder(
        uint128 restaurantId,
        uint128[] memory itemIds,
        uint128[] memory quantities
    ) external payable onlyCustomer nonReentrant {
        if (orderManager == address(0)) revert FoodApp__ManagerNotSet("OrderManager");
        if (restaurantManager == address(0) || !IRestaurantManager(restaurantManager).restaurantExists(restaurantId)) {
            revert FoodApp__InvalidRestaurantId();
        }
        IOrderManager(orderManager).placeOrder{value: msg.value}(msg.sender, restaurantId, itemIds, quantities);
    }

    function cancelCustomerOrder(uint128 orderId) external onlyCustomer nonReentrant {
        if (orderManager == address(0)) revert FoodApp__ManagerNotSet("OrderManager");
        IOrderManager(orderManager).cancelOrder(msg.sender, orderId);
    }

    // Modifier để kiểm tra staff của một nhà hàng cụ thể
    modifier onlyStaffOfSpecificRestaurant(uint128 _restaurantId) {
        if (!_isStaffOfRestaurant(msg.sender, _restaurantId)) {
            revert FoodApp__NotRestaurantStaff();
        }
        _;
    }

    function completeStaffOrder(uint128 orderId) external nonReentrant {
        if (orderManager == address(0)) revert FoodApp__ManagerNotSet("OrderManager");
        Order memory order = IOrderManager(orderManager).getOrder(orderId); 

        if (!_isStaffOfRestaurant(msg.sender, order.restaurantId)) {
            revert FoodApp__NotRestaurantStaff();
        }
        IOrderManager(orderManager).completeOrder(msg.sender, orderId, order.restaurantId);
    }

    function updateStaffOrderStatus(uint128 orderId, OrderStatus newStatus) external nonReentrant { 
        if (orderManager == address(0)) revert FoodApp__ManagerNotSet("OrderManager");
        Order memory order = IOrderManager(orderManager).getOrder(orderId);

        if (!_isStaffOfRestaurant(msg.sender, order.restaurantId)) {
            revert FoodApp__NotRestaurantStaff();
        }
        IOrderManager(orderManager).updateOrderStatus(msg.sender, orderId, newStatus, order.restaurantId);
    }

    // ------------ View Management -----------------------------------------------------------
    function rateExistingRestaurant(uint128 restaurantId, uint8 rating, string memory comment) external onlyCustomer {
        if (reviewManager == address(0)) revert FoodApp__ManagerNotSet("ReviewManager");
        if (restaurantManager == address(0) || !IRestaurantManager(restaurantManager).restaurantExists(restaurantId)) {
            revert FoodApp__InvalidRestaurantId();
        }
        IReviewManager(reviewManager).rateRestaurant(msg.sender, restaurantId, rating, comment);
    }

    // --- View Functions (Managers) ---
    // Hàm này cần IRestaurantManager có hàm getRestaurant trả về Restaurant struct
    // function getRestaurantDetails(uint128 restaurantId) external view returns (Restaurant memory) {
    //     if (restaurantManager == address(0)) revert FoodApp__ManagerNotSet("RestaurantManager");
    //     if (!IRestaurantManager(restaurantManager).restaurantExists(restaurantId)) revert FoodApp__InvalidRestaurantId();
    //     return IRestaurantManager(restaurantManager).getRestaurant(restaurantId);
    // }

    function getMenuItemFromRestaurant(uint128 restaurantId, uint128 menuId) external view returns (MenuItem memory) {
        if (menuManager == address(0)) revert FoodApp__ManagerNotSet("MenuManager");
        return IMenuManager(menuManager).getMenuItem(restaurantId, menuId);
    }

    function getCustomerOrder(uint128 orderId) external view returns (Order memory) {
        if (orderManager == address(0)) revert FoodApp__ManagerNotSet("OrderManager");
        Order memory order = IOrderManager(orderManager).getOrder(orderId);

        bool isOrderActualOwner = msg.sender == order.customer;
        bool isAppAdmin = roles[msg.sender] == Role.Admin;
        bool isOrderRelatedStaff = _isStaffOfRestaurant(msg.sender, order.restaurantId);

        if (!isOrderActualOwner && !isAppAdmin && !isOrderRelatedStaff) {
            revert FoodApp__NotAuthorized();
        }
        return order;
    }
}