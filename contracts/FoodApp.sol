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
import "../interfaces/IUserProfileManager.sol";
import "../interfaces/ITableManager.sol";
import "../interfaces/ICategoriesManager.sol";
import "../structs/FoodTypes.sol";

contract FoodApp is OwnableUpgradeable, ReentrancyGuardUpgradeable, RoleAccess {
    FoodAppFactory public factory;
    address public restaurantManager; 
    address public menuManager;       
    address public orderManager;        
    address public reviewManager;  
    address public userProfileManager;   
    address public tableManager;  
    address public categoriesManager;
    event ManagerDeployed(string managerType, address managerAddress);
    // Thêm các event cho các hành động của FoodApp

    event RestaurantRegisteredInApp(uint128 indexed restaurantId, address indexed owner);
    event RoleGrantedInApp(address indexed account, Role indexed role);
    event StaffAssignedInApp(address indexed staff, uint128 indexed restaurantId, Role staffRole);
    event StaffProfileCreatedOrUpdated(address indexed staffAccount, string staffName);

    error FoodApp__InvalidFactoryAddress();
    error FoodApp__ManagerAlreadyDeployed(string managerType);
    error FoodApp__ManagerNotSet(string managerType);
    error FoodApp__DependencyNotDeployed(string managerType);
    error FoodApp__InvalidRestaurantId();
    error FoodApp__NotAuthorized(); 
    error FoodApp__NotRestaurantStaff();
    error FoodApp__ActionNotAllowedForRole();
    error FoodApp__MenuItemNotFound(uint128 restaurantId, uint128 menuItemId);
    error FoodApp__MenuItemNotAvailable(uint128 menuItemId);
    error FoodApp__InvalidOrderData();
    error FoodApp__UserProfileManagerNotSet();
    error FoodApp__InvalidServingStaff();
    error FoodApp__TableNumberRequiredForDineIn();
    error FoodApp__TableManagerNotSet();
    error FoodApp__CategoriesManagerNotSet();

//------Modify cấp quyền sau khi các func thực thi
    modifier onlyCustomerOrUpgrade() {
        bool isAdmin = roles[msg.sender] == Role.Admin;
        bool isCustomer = roles[msg.sender] == Role.Customer;

        if (!isAdmin && !isCustomer) {
            if (roles[msg.sender] == Role.None) { 
                _grantRoleInternal(msg.sender, Role.Customer);
                emit RoleGrantedInApp(msg.sender, Role.Customer); 
            } else {
                revert FoodApp__ActionNotAllowedForRole();
            }
        }
        _;
    }
//--------- Modifier này kiểm tra xem msg.sender có phải là Admin của FoodApp,
    // HOẶC là chủ sở hữu của nhà hàng, HOẶC là nhân viên được gán cho nhà hàng đó.
    modifier onlyRestaurantPrivileged(uint128 _restaurantId) {
         if (roles[msg.sender] == Role.Admin) {
    } else if (restaurantManager != address(0) && 
               IRestaurantManager(restaurantManager).restaurantExists(_restaurantId) &&
               IRestaurantManager(restaurantManager).getRestaurantOwner(_restaurantId) == msg.sender) {
    } else if (_isStaffOfRestaurant(msg.sender, _restaurantId)) {
    } else {
        revert FoodApp__NotAuthorized();
    }
    _;
    }
//----------Modifier để kiểm tra staff của một nhà hàng cụ thể
    modifier onlyStaffOfSpecificRestaurant(uint128 _restaurantId) {
        if (!_isStaffOfRestaurant(msg.sender, _restaurantId)) {
            revert FoodApp__NotRestaurantStaff();
        }
        _;
    }

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
    function deployCategoriesManager() external onlyOwner {
        if (categoriesManager != address(0)) revert FoodApp__ManagerAlreadyDeployed("CategoriesManager");
        if (restaurantManager == address(0)) revert FoodApp__DependencyNotDeployed("RestaurantManager for CategoriesManager");
        categoriesManager = factory.deployManager("CategoriesManager");
        emit ManagerDeployed("CategoriesManager", categoriesManager);
    }

    function deployMenuManager() external onlyOwner {
        if (menuManager != address(0)) revert FoodApp__ManagerAlreadyDeployed("MenuManager");
        if (categoriesManager == address(0)) revert FoodApp__DependencyNotDeployed("CategoriesManager for MenuManager");
        if (restaurantManager == address(0)) revert FoodApp__DependencyNotDeployed("RestaurantManager for MenuManager");
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
        if (restaurantManager == address(0)) revert FoodApp__DependencyNotDeployed("RestaurantManager");
        if (menuManager == address(0)) revert FoodApp__DependencyNotDeployed("MenuManager");
        reviewManager = factory.deployManager("ReviewManager");
        emit ManagerDeployed("ReviewManager", reviewManager);
    }

    function deployUserProfileManager() external onlyOwner { 
        if (userProfileManager != address(0)) revert FoodApp__ManagerAlreadyDeployed("UserProfileManager");
        if (address(factory) == address(0)) revert FoodApp__InvalidFactoryAddress(); 

        userProfileManager = factory.deployManager("UserProfileManager");
        emit ManagerDeployed("UserProfileManager", userProfileManager); 
    }
    function deployTableManager() external onlyOwner {
        if (tableManager != address(0)) revert FoodApp__ManagerAlreadyDeployed("TableManager");
        if (restaurantManager == address(0)) revert FoodApp__DependencyNotDeployed("RestaurantManager for TableManager");
        tableManager = factory.deployManager("TableManager"); 
        if (orderManager != address(0) && tableManager != address(0)) {
        }
        emit ManagerDeployed("TableManager", tableManager);
    }

    // --- Role Management (by FoodApp Admin) ---
    // Hàm onlyAdmin được kế thừa từ RoleAccess và kiểm tra roles[msg.sender] == Role.Admin
    function grantAppRole(address account, Role role) external onlyAdmin {
        _grantRoleInternal(account, role);
        emit RoleGrantedInApp(account, role);
    }

    function revokeAppRole(address account) external onlyAdmin {
        _revokeRoleInternal(account);
    }

    function assignStaffMemberToRestaurant(address staffAccount, uint128 restaurantId, Role staffRole,
        string calldata staffName,
        string calldata staffPhoneNumber,
        uint128 staffCCCD,
        string calldata staffEmail,
        string calldata staffImageUrl) external onlyAdmin {
        if (restaurantManager == address(0)) revert FoodApp__ManagerNotSet("RestaurantManager");
        if (!IRestaurantManager(restaurantManager).restaurantExists(restaurantId)) revert FoodApp__InvalidRestaurantId();
        if (staffRole != Role.FOH && staffRole != Role.BOH) revert FoodApp__ActionNotAllowedForRole();
        if (staffAccount == address(0)) revert FoodApp__NotAuthorized();

        if (userProfileManager == address(0)) revert FoodApp__UserProfileManagerNotSet();
        IUserProfileManager(userProfileManager).createOrUpdateUserProfile(
            staffAccount,
            staffName,
            staffPhoneNumber,
            staffCCCD,
            staffEmail,
            staffImageUrl
        );
        emit StaffProfileCreatedOrUpdated(staffAccount, staffName);
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
    

    function addMenuItemToRestaurant(
        uint128 restaurantId,
        string memory name,
        string memory menuTitle,
        string memory imageUrl,
        uint128 price,
        string memory description,
        uint128 categoryId,
        uint128 preparationTime
    ) external onlyRestaurantPrivileged(restaurantId) {
        if (menuManager == address(0)) revert FoodApp__ManagerNotSet("MenuManager");
        if (restaurantManager == address(0) || !IRestaurantManager(restaurantManager).restaurantExists(restaurantId)) {
             revert FoodApp__InvalidRestaurantId();
        }
        IMenuManager(menuManager).addMenuItem(restaurantId, name, menuTitle, imageUrl, price, description, categoryId, preparationTime);
    }

    function updateMenuItemDetails( UpdateMenuItemParams memory params
    ) external onlyRestaurantPrivileged(params.restaurantId) {
        if (menuManager == address(0)) revert FoodApp__ManagerNotSet("MenuManager");
        if (restaurantManager == address(0) || !IRestaurantManager(restaurantManager).restaurantExists(params.restaurantId)) {
             revert FoodApp__InvalidRestaurantId();
        }

        IMenuManager(menuManager).updateMenuItem(params);
    }
    function addRestaurantTable(
        uint128 _restaurantId,
        string memory _tableNumber
    ) external onlyRestaurantPrivileged(_restaurantId) returns (uint128 newTableId) {
        if (tableManager == address(0)) revert FoodApp__TableManagerNotSet();

        if (restaurantManager == address(0) || !IRestaurantManager(restaurantManager).restaurantExists(_restaurantId)) {
             revert FoodApp__InvalidRestaurantId();
        }
        newTableId = ITableManager(tableManager).addTable(_restaurantId, _tableNumber);
        return newTableId;
    }

    function addRestaurantCategory(
        uint128 _restaurantId,
        string memory _name,
        string memory _description
    ) external onlyRestaurantPrivileged(_restaurantId) returns (uint128 newCategoryId) {
        if (categoriesManager == address(0)) revert FoodApp__CategoriesManagerNotSet();
        if (!IRestaurantManager(restaurantManager).restaurantExists(_restaurantId)) revert FoodApp__InvalidRestaurantId(); 

        newCategoryId = ICategoriesManager(categoriesManager).addRestaurantCategory(_restaurantId, _name, _description);
        // emit RestaurantCategoryAddedInApp(newCategoryId, _restaurantId, _name, msg.sender);
        return newCategoryId;
    }

    function updateRestaurantCategoryDetails(
        uint128 _categoryId,
        string memory _newName,
        string memory _newDescription,
        bool _isActive
    ) external { 
        if (categoriesManager == address(0)) revert FoodApp__CategoriesManagerNotSet();
        uint128 restaurantIdOfCategory = ICategoriesManager(categoriesManager).getCategoryById(_categoryId).restaurantId;

        if (roles[msg.sender] != Role.Admin &&
            !(IRestaurantManager(restaurantManager).restaurantExists(restaurantIdOfCategory) &&
              IRestaurantManager(restaurantManager).getRestaurantOwner(restaurantIdOfCategory) == msg.sender)
           ) {
            revert FoodApp__NotAuthorized();
        }

        ICategoriesManager(categoriesManager).updateRestaurantCategory(_categoryId, _newName, _newDescription, _isActive);
        // emit RestaurantCategoryUpdatedInApp(_categoryId, msg.sender);
    }

    // --- Order Management ---
    function placeCustomerOrder(
        uint128 restaurantId,
        uint128[] memory itemIds,
        uint128[] memory quantities,
        address _servingStaffEoa,
        string memory _tableNumber
    ) external payable onlyCustomerOrUpgrade nonReentrant {
        if (orderManager == address(0)) revert FoodApp__ManagerNotSet("OrderManager");
        // if (menuManager == address(0)) revert FoodApp__ManagerNotSet("MenuManager");
        if (restaurantManager == address(0) || !IRestaurantManager(restaurantManager).restaurantExists(restaurantId)) {
            revert FoodApp__InvalidRestaurantId();
        }
        if (_servingStaffEoa != address(0)) {
            if (!_isStaffOfRestaurant(_servingStaffEoa, restaurantId)) {
                revert FoodApp__InvalidServingStaff();
            }
            Role staffRole = roles[_servingStaffEoa];
            if (staffRole != Role.FOH) {
                revert FoodApp__ActionNotAllowedForRole(); 
            }
        }
    //     for (uint i = 0; i < itemIds.length; i++) {
    //     MenuItem memory item = IMenuManager(menuManager).getMenuItem(restaurantId, itemIds[i]);
    //     if (item.id == 0) revert FoodApp__MenuItemNotFound(restaurantId, itemIds[i]);
    //     if (!item.available) revert FoodApp__MenuItemNotAvailable(itemIds[i]);
    //     if (quantities[i] == 0) revert FoodApp__InvalidOrderData();
    // }
        IOrderManager(orderManager).placeOrder{value: msg.value}(msg.sender, restaurantId, itemIds, quantities, _servingStaffEoa, _tableNumber);
    }

    function cancelCustomerOrder(uint128 orderId) external onlyCustomer nonReentrant {
        if (orderManager == address(0)) revert FoodApp__ManagerNotSet("OrderManager");
        IOrderManager(orderManager).cancelOrder(msg.sender, orderId);
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

    function getSuggestedMenuItemsByRestaurant(uint128 _restaurantId, uint256 maxItemsToReturn)
        external view
        returns (SuggestedMenuItem[] memory) 
    {
        if (orderManager == address(0)) revert FoodApp__ManagerNotSet("OrderManager");
        if (menuManager == address(0)) revert FoodApp__ManagerNotSet("MenuManager");
        if (restaurantManager == address(0)) revert FoodApp__ManagerNotSet("RestaurantManager");
        if (categoriesManager == address(0)) revert FoodApp__CategoriesManagerNotSet();
        if (!IRestaurantManager(restaurantManager).restaurantExists(_restaurantId)) {
            revert FoodApp__InvalidRestaurantId();
        }
        uint128[] memory completedItemIdsFromOrderManager = IOrderManager(orderManager).getRestaurantCompletedMenuItemIds(_restaurantId);

        if (completedItemIdsFromOrderManager.length == 0) {
            return new SuggestedMenuItem[](0);
        }

        uint256 internalProcessingLimit = 50; 
        uint256 numIdsToProcess = completedItemIdsFromOrderManager.length;

        if (maxItemsToReturn > 0 && maxItemsToReturn < numIdsToProcess) {
            numIdsToProcess = maxItemsToReturn;
        }
        if (numIdsToProcess > internalProcessingLimit) {
            numIdsToProcess = internalProcessingLimit;
        }

        SuggestedMenuItem[] memory tempSuggestedItems = new SuggestedMenuItem[](numIdsToProcess);
        uint256 actualCount = 0; 

        for (uint i = 0; i < numIdsToProcess && actualCount < maxItemsToReturn ; i++) {
            uint128 menuItemId = completedItemIdsFromOrderManager[i];
            MenuItem memory itemInfo;
            bool menuItemExists = true;
            try IMenuManager(menuManager).getMenuItem(_restaurantId, menuItemId) returns (MenuItem memory mi) {
                itemInfo = mi;
            } catch { menuItemExists = false; }

            if (menuItemExists && itemInfo.id != 0) {
                uint256 orderCount = IOrderManager(orderManager).getCompletedOrderItemCount(_restaurantId, menuItemId);
                if (orderCount > 0) {
                    string memory categoryName = "";
                    if (itemInfo.categoryId != 0) { 
                        try ICategoriesManager(categoriesManager).getCategoryById(itemInfo.categoryId) returns (Category memory cat) {
                            if(cat.id != 0 && cat.isActive) { 
                                categoryName = cat.name;
                            }
                        } catch { /* category không tìm thấy*/ }
                    }

                    tempSuggestedItems[actualCount] = SuggestedMenuItem({
                        menuItemId: itemInfo.id,
                        name: itemInfo.name,
                        imageUrl: itemInfo.imageUrl,
                        price: itemInfo.price,
                        categoryId: itemInfo.categoryId,
                        categoryName: categoryName, 
                        completedOrderCount: orderCount
                    });
                    actualCount++;
                }
            }
        }
        SuggestedMenuItem[] memory finalSuggestedItems = new SuggestedMenuItem[](actualCount);
        for (uint i = 0; i < actualCount; i++) {
            finalSuggestedItems[i] = tempSuggestedItems[i];
        }

        return finalSuggestedItems;
    }

    function updateRestaurantTable(
        uint128 _tableId,
        string memory _newTableNumber,
        bool _isActive
    ) external { 
        if (tableManager == address(0)) revert FoodApp__TableManagerNotSet();
        uint128 restaurantIdOfTable = ITableManager(tableManager).getTable(_tableId).restaurantId;
        bool isPrivileged = false;
        if (roles[msg.sender] == Role.Admin) {
            isPrivileged = true;
        } else if (restaurantManager != address(0) &&
                   IRestaurantManager(restaurantManager).restaurantExists(restaurantIdOfTable) &&
                   IRestaurantManager(restaurantManager).getRestaurantOwner(restaurantIdOfTable) == msg.sender) {
            isPrivileged = true;
        } else if (_isStaffOfRestaurant(msg.sender, restaurantIdOfTable)) { 
            isPrivileged = true;
        }
        if (!isPrivileged) {
            revert FoodApp__NotAuthorized(); 
        }
        ITableManager(tableManager).updateTable(_tableId, _newTableNumber, _isActive);

    }
//========= Hàm Rating ===================
    // function rateRestaurant(uint128 restaurantId, uint8 rating, string memory comment) external onlyCustomer {
    //     if (reviewManager == address(0)) revert FoodApp__ManagerNotSet("ReviewManager");
    //     if (restaurantManager == address(0) || !IRestaurantManager(restaurantManager).restaurantExists(restaurantId)) {
    //         revert FoodApp__InvalidRestaurantId();
    //     }
    //     IReviewManager(reviewManager).rateRestaurant(msg.sender, restaurantId, rating, comment);
    // }

    function rateStaff(address staff, uint128 restaurantId, uint8 rating, string memory comment) 
        external onlyCustomer {
        if (reviewManager == address(0)) revert FoodApp__ManagerNotSet("ReviewManager");
        if (restaurantManager == address(0) || !IRestaurantManager(restaurantManager).restaurantExists(restaurantId)) {
            revert FoodApp__InvalidRestaurantId();
        }
        if (staff == address(0)) revert FoodApp__NotAuthorized();
        if (!_isStaffOfRestaurant(staff, restaurantId)) revert FoodApp__NotRestaurantStaff();
        IReviewManager(reviewManager).rateStaff(msg.sender, staff, restaurantId, rating, comment);
    }

    function rateMenuItem(uint128 restaurantId, uint128 menuItemId, uint8 rating, string memory comment)
        external onlyCustomer {
        if (reviewManager == address(0)) revert FoodApp__ManagerNotSet("ReviewManager");
        if (restaurantManager == address(0)) revert FoodApp__ManagerNotSet("RestaurantManager"); 
        if (!IRestaurantManager(restaurantManager).restaurantExists(restaurantId)) {
            revert FoodApp__InvalidRestaurantId();
        }
        if (menuManager == address(0)) revert FoodApp__ManagerNotSet("MenuManager");

        MenuItem memory currentItem = IMenuManager(menuManager).getMenuItem(restaurantId, menuItemId);
        if (currentItem.id == 0) revert FoodApp__MenuItemNotFound(restaurantId, menuItemId);

        (uint128 newTotalRating, uint128 newRatingCount) = IReviewManager(reviewManager).rateMenuItem(msg.sender, restaurantId, menuItemId, rating, comment);

        UpdateMenuItemParams memory params = UpdateMenuItemParams({
            restaurantId: restaurantId,
            menuId: menuItemId,
            name: currentItem.name, 
            menuTitle: currentItem.menuTitle,
            imageUrl: currentItem.imageUrl,
            price: currentItem.price,
            available: currentItem.available,
            description: currentItem.description,
            categoryId: currentItem.categoryId,
            preparationTime: currentItem.preparationTime,
            totalRating: newTotalRating,
            ratingCount: newRatingCount
        });
        IMenuManager(menuManager).updateMenuItem(params); 
    }

    // --- View Functions (Managers) ---------------------------------------------------------

    // function getCustomerOrder(uint128 orderId) external view returns (Order memory) {
    //     if (orderManager == address(0)) revert FoodApp__ManagerNotSet("OrderManager");
    //     Order memory order = IOrderManager(orderManager).getOrder(orderId);

    //     bool isOrderActualOwner = msg.sender == order.customer;
    //     bool isAppAdmin = roles[msg.sender] == Role.Admin;
    //     bool isOrderRelatedStaff = _isStaffOfRestaurant(msg.sender, order.restaurantId);

    //     if (!isOrderActualOwner && !isAppAdmin && !isOrderRelatedStaff) {
    //         revert FoodApp__NotAuthorized();
    //     }
    //     return order;
    // }

//=========================== View Func MenuManager ====================

    // function getMenuItemFromRestaurant(uint128 restaurantId, uint128 menuId) external view returns (MenuItem memory) {
    //     if (menuManager == address(0)) revert FoodApp__ManagerNotSet("MenuManager");
    //     return IMenuManager(menuManager).getMenuItem(restaurantId, menuId);
    // }

    // Lấy tất cả menu items của một nhà hàng 
    // function getAllMenuItemsOfRestaurant(uint128 restaurantId) external view returns (MenuItem[] memory) {
    //     if (menuManager == address(0)) revert FoodApp__ManagerNotSet("MenuManager");
    //     if (restaurantManager == address(0) || !IRestaurantManager(restaurantManager).restaurantExists(restaurantId)) {
    //         revert FoodApp__InvalidRestaurantId();
    //     }
    //     return IMenuManager(menuManager).getMenuItemsByRestaurant(restaurantId);
    // }

    // // Lấy tất cả menu item IDs của một nhà hàng
    // function getAllMenuItemIdsOfRestaurant(uint128 restaurantId) external view returns (uint128[] memory) {
    //     if (menuManager == address(0)) revert FoodApp__ManagerNotSet("MenuManager");
    //     if (restaurantManager == address(0) || !IRestaurantManager(restaurantManager).restaurantExists(restaurantId)) {
    //         revert FoodApp__InvalidRestaurantId();
    //     }
    //     return IMenuManager(menuManager).getMenuItemIdsByRestaurant(restaurantId);
    // }

//====================== View Function RestaurantManager==========================

    // function getRestaurantOwner(uint128 restaurantId) external view returns (address) {
    //     if (restaurantManager == address(0)) revert FoodApp__ManagerNotSet("RestaurantManager");
    //     return IRestaurantManager(restaurantManager).getRestaurantOwner(restaurantId);
    // }

//======================= View Function OrderManager=========================

    // function getMyOrders(uint256 startIndex, uint256 limit) 
    // external view onlyCustomer returns (Order[] memory ordersAn, uint256 nextStartIndex) {
    //     if (orderManager == address(0)) revert FoodApp__ManagerNotSet("OrderManager");
    //     return IOrderManager(orderManager).getOrdersByCustomer(msg.sender, startIndex, limit);
    // }

    // function getMyOrderCount() 
    // external view onlyCustomer returns (uint256) {
    //     if (orderManager == address(0)) revert FoodApp__ManagerNotSet("OrderManager");
    //     return IOrderManager(orderManager).getOrderCountByCustomer(msg.sender);
    // }

    // function getOrdersForSpecificCustomer(address customerEoa, uint256 startIndex, uint256 limit) 
    // external view onlyAdmin returns (Order[] memory ordersAn, uint256 nextStartIndex) {
    //     if (orderManager == address(0)) revert FoodApp__ManagerNotSet("OrderManager");
    //     return IOrderManager(orderManager).getOrdersByCustomer(customerEoa, startIndex, limit);
    // }

    // function getOrderCountForSpecificCustomer(address customerEoa) 
    // external view onlyAdmin returns (uint256) {
    //     if (orderManager == address(0)) revert FoodApp__ManagerNotSet("OrderManager");
    //     return IOrderManager(orderManager).getOrderCountByCustomer(customerEoa);
    // }

//====================== View Review Manager ==============================

    // function getStaffReviews(address staff) external view returns (StaffReview[] memory) {
    //     if (reviewManager == address(0)) revert FoodApp__ManagerNotSet("ReviewManager");
    //     return IReviewManager(reviewManager).getStaffReviews(staff);
    // }

    // function getMenuItemReviews(uint128 menuItemId) external view returns (MenuItemReview[] memory) {
    //     if (reviewManager == address(0)) revert FoodApp__ManagerNotSet("ReviewManager");
    //     return IReviewManager(reviewManager).getMenuItemReviews(menuItemId);
    // }

    // function getAverageStaffRating(address staff) external view returns (uint128 averageRating, uint128 ratingCount) {
    //     if (reviewManager == address(0)) revert FoodApp__ManagerNotSet("ReviewManager");
    //     return IReviewManager(reviewManager).getAverageStaffRating(staff);
    // }

    // function getAverageMenuItemRating(uint128 menuItemId) external view returns (uint128 averageRating, uint128 ratingCount) {
    //     if (reviewManager == address(0)) revert FoodApp__ManagerNotSet("ReviewManager");
    //     return IReviewManager(reviewManager).getAverageMenuItemRating(menuItemId);
    // }

//===================== View User Profile Manager ====================================
    // function getStaffMemberDetails(address staffAccount, uint128 restaurantId)
    //     external view
    //     returns (StaffMemberDetails memory staffDetails)
    // {
    //     if (staffAccount == address(0)) revert FoodApp__NotAuthorized();
    //     if (userProfileManager == address(0)) revert FoodApp__UserProfileManagerNotSet();
    //     if (restaurantManager == address(0)) revert FoodApp__ManagerNotSet("RestaurantManager");

    //     if (!IRestaurantManager(restaurantManager).restaurantExists(restaurantId)) {
    //         revert FoodApp__InvalidRestaurantId();
    //     }

    //     UserProfile memory profile = IUserProfileManager(userProfileManager).getUserProfile(staffAccount);

    //     bool isActuallyStaff = super._isStaffOfRestaurant(staffAccount, restaurantId); 
    //     require(isActuallyStaff, "FoodApp: Account is not an active staff of this restaurant.");

    //     Role staffRole = roles[staffAccount]; 

    //     uint128 assignmentDt = 0;
    //     if (isActuallyStaff) { 
    //          assignmentDt = super._getStaffAssignmentDateInternal(staffAccount, restaurantId);
    //     }

    //     staffDetails = StaffMemberDetails({
    //         staffAddress: profile.userAddress,
    //         name: profile.name,
    //         phoneNumber: profile.phoneNumber,
    //         CCCD: profile.CCCD,
    //         email: profile.email,
    //         imageUrl: profile.imageUrl,
    //         isActiveProfile: profile.isActive,
    //         registrationDate: profile.registrationDate,
    //         restaurantId: restaurantId, 
    //         staffRoleInRestaurant: staffRole,
    //         assignmentDate: assignmentDt 
    //     });

    //     return staffDetails;
    // }
    // function getAllStaffOfRestaurant(uint128 _restaurantId)
    //     external view
    //     returns (StaffMemberDetails[] memory)
    // {   
    //     if (restaurantManager == address(0)) revert FoodApp__ManagerNotSet("RestaurantManager");
    //     if (!IRestaurantManager(restaurantManager).restaurantExists(_restaurantId)) revert FoodApp__InvalidRestaurantId();
    //     if (userProfileManager == address(0)) revert FoodApp__UserProfileManagerNotSet();
    //     address[] memory staffAddresses = super._getStaffAddressesForRestaurantInternal(_restaurantId);
    //     StaffMemberDetails[] memory allStaffDetails = new StaffMemberDetails[](staffAddresses.length);
    //     for (uint i = 0; i < staffAddresses.length; i++) {
    //         address currentStaffAddress = staffAddresses[i];
    //         UserProfile memory profile = IUserProfileManager(userProfileManager).getUserProfile(currentStaffAddress);
    //         Role staffRole = roles[currentStaffAddress]; 
    //         uint128 assignmentDt = 0;
    //         assignmentDt = super._getStaffAssignmentDateInternal(currentStaffAddress, _restaurantId);
    //         allStaffDetails[i] = StaffMemberDetails({
    //             staffAddress: currentStaffAddress,
    //             name: profile.name,
    //             phoneNumber: profile.phoneNumber,
    //             CCCD: profile.CCCD,
    //             email: profile.email,
    //             imageUrl: profile.imageUrl,
    //             isActiveProfile: profile.isActive,
    //             registrationDate: profile.registrationDate,
    //             restaurantId: _restaurantId,
    //             staffRoleInRestaurant: staffRole,
    //             assignmentDate: assignmentDt
    //         });
    //     }
    //     return allStaffDetails;
    // }
//=============== View Table Manager =======================

        // function getRestaurantTables(uint128 _restaurantId) external view returns (Table[] memory) {
        //     if (tableManager == address(0)) revert FoodApp__ManagerNotSet("TableManager");
        //     return ITableManager(tableManager).getTablesByRestaurant(_restaurantId);
        // }

        // function getSpecificTable(uint128 _tableId) external view returns (Table memory) {
        //     if (tableManager == address(0)) revert FoodApp__ManagerNotSet("TableManager");
        //     return ITableManager(tableManager).getTable(_tableId);
        // }
        // function checkTableExistsInRestaurant(uint128 _restaurantId, string memory _tableNumber) external view returns (bool) {
        //     if (tableManager == address(0)) revert FoodApp__TableManagerNotSet();
        //     return ITableManager(tableManager).tableExists(_restaurantId, _tableNumber);
        // }

}