// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

import "@openzeppelin/contracts-upgradeable/access/OwnableUpgradeable.sol";
import "../structs/FoodTypes.sol";
import "../interfaces/IMenuManager.sol";
import "../interfaces/ICategoriesManager.sol"; 
import "../interfaces/IRestaurantManager.sol";

contract MenuManager is OwnableUpgradeable, IMenuManager {
    mapping(uint128 => mapping(uint128 => MenuItem)) public menuItems;
    mapping(uint128 => uint128) public nextMenuIds; 
    mapping(uint128 => uint128[]) internal restaurantMenuItemIds;

    ICategoriesManager public categoriesManager; 
    IRestaurantManager public restaurantManager;

    address public foodAppContractAddress; 

    event MenuItemAdded(uint128 indexed restaurantId, uint128 indexed menuId, string name, uint128 price);
    event MenuItemUpdated(uint128 indexed restaurantId, uint128 indexed menuId, string name, uint128 price, bool available);
    event MenuItemRemoved(uint128 indexed restaurantId, uint128 indexed menuId, uint128 removedIndex);
    // event MenuItemQuantityUpdated(uint128 indexed restaurantId, uint128 indexed menuId, uint128 newQuantityAvailable);
    
    error MenuManager__NotFoodApp();
    error MenuManager__InvalidAddress();
    error InvalidAddress();
    error MenuManager__NameRequired();
    error MenuManager__InvalidPrice();
    error MenuManager__MenuItemNotFound();
    error MenuManager__RestaurantHasNoMenuYet();
    error MenuManager__InsufficientQuantity(uint128 menuItemId, uint128 requestedQuantity, uint128 availableQuantity);
    // error MenuManager__QuantityCannotBeZeroOnAdd();
    error MenuManager__CategoriesManagerNotSet();
    error MenuManager__CategoryNotValidForRestaurant(uint128 categoryId, uint128 restaurantId);
    error MenuManager__RestaurantManagerNotSet();
    


    modifier onlyFoodAppContract() {
        if (msg.sender != foodAppContractAddress) revert MenuManager__NotFoodApp();
        _;
    }

    function initialize(address _foodAppContract, address _categoriesManagerAddress, address _restaurantManagerAddress, address _owner) public initializer {
        if (_foodAppContract == address(0)) revert MenuManager__InvalidAddress(); 
        if (_owner == address(0)) revert MenuManager__InvalidAddress();
        if (_categoriesManagerAddress == address(0)) revert InvalidAddress(); 
        if (_restaurantManagerAddress == address(0)) revert InvalidAddress();
        __Ownable_init(_owner);
        foodAppContractAddress = _foodAppContract;
        categoriesManager = ICategoriesManager(_categoriesManagerAddress);
        restaurantManager = IRestaurantManager(_restaurantManagerAddress);
    }


    function addMenuItem(
        uint128 restaurantId,
        string memory name,
        string memory menuTitle,
        string memory imageUrl,
        uint128 price,
        string memory description,
        uint128 _categoryId,
        uint128 preparationTime
        // uint128 initialQuantity 
    ) external override onlyFoodAppContract {
        if (bytes(name).length == 0) revert MenuManager__NameRequired();
        if (price == 0) revert MenuManager__InvalidPrice(); 
        // if (initialQuantity == 0) revert MenuManager__QuantityCannotBeZeroOnAdd();

        if (nextMenuIds[restaurantId] == 0) { 
            nextMenuIds[restaurantId] = 1;
        }
        if (address(categoriesManager) == address(0)) revert MenuManager__CategoriesManagerNotSet();
        if (address(restaurantManager) == address(0)) revert MenuManager__RestaurantManagerNotSet();

        uint128 menuId = nextMenuIds[restaurantId];
        nextMenuIds[restaurantId]++;

        menuItems[restaurantId][menuId] = MenuItem({
            id: menuId,
            restaurantId: restaurantId,
            name: name,
            menuTitle: menuTitle,
            imageUrl: imageUrl,
            price: price,
            available: true,
            description: description,
            categoryId: _categoryId,
            totalRating: 0,
            ratingCount: 0,
            preparationTime: preparationTime
            // quantityAvailable: initialQuantity
        });

        restaurantMenuItemIds[restaurantId].push(menuId);
        emit MenuItemAdded(restaurantId, menuId, name, price);
    }

    function updateMenuItem(
        UpdateMenuItemParams memory params
    ) external override onlyFoodAppContract {
        MenuItem storage itemToUpdate = menuItems[params.restaurantId][params.menuId];
        if (itemToUpdate.id == 0) revert MenuManager__MenuItemNotFound();

        if (bytes(params.name).length == 0) revert MenuManager__NameRequired();
        if (params.price == 0) revert MenuManager__InvalidPrice();
        if (address(categoriesManager) == address(0)) revert MenuManager__CategoriesManagerNotSet();
        if (params.categoryId != itemToUpdate.categoryId) { 
             if (!categoriesManager.categoryExists(params.restaurantId, params.categoryId)) {
                revert MenuManager__CategoryNotValidForRestaurant(params.categoryId, params.restaurantId);
            }
        }

        itemToUpdate.name = params.name;
        itemToUpdate.menuTitle = params.menuTitle;
        itemToUpdate.imageUrl = params.imageUrl;
        itemToUpdate.price = params.price;
        itemToUpdate.available = params.available;
        itemToUpdate.description = params.description;
        itemToUpdate.categoryId = params.categoryId;
        itemToUpdate.preparationTime = params.preparationTime;
        // itemToUpdate.quantityAvailable = params.newQuantity;

        emit MenuItemUpdated(params.restaurantId, params.menuId, params.name, params.price, params.available);
        // emit MenuItemQuantityUpdated(params.restaurantId, params.menuId, params.newQuantity);
    }

    function removeMenuItem(
        uint128 restaurantId,
        uint128 menuId
    ) external override onlyFoodAppContract {
        if (menuItems[restaurantId][menuId].id == 0) revert MenuManager__MenuItemNotFound();
        delete menuItems[restaurantId][menuId];
         uint128[] storage itemIds = restaurantMenuItemIds[restaurantId];
        uint removedIndex = type(uint).max;
        for (uint i = 0; i < itemIds.length; i++) {
            if (itemIds[i] == menuId) {
                itemIds[i] = itemIds[itemIds.length - 1];
                itemIds.pop();
                removedIndex = i;
                break;
            }
        }
        if(removedIndex == type(uint).max) revert MenuManager__MenuItemNotFound();
        emit MenuItemRemoved(restaurantId, menuId, uint128(removedIndex));
    }

    // function decreaseMenuItemQuantity(
    //     uint128 restaurantId,
    //     uint128 menuId,
    //     uint128 quantityToDecrease
    // ) external { 
    //     MenuItem storage item = menuItems[restaurantId][menuId];
    //     if (item.id == 0) revert MenuManager__MenuItemNotFound();
    //     if (item.quantityAvailable < quantityToDecrease) {
    //         revert MenuManager__InsufficientQuantity(menuId, quantityToDecrease, item.quantityAvailable);
    //     }
    //     item.quantityAvailable -= quantityToDecrease;
    // }
    // function increaseMenuItemQuantity(
    //     uint128 restaurantId,
    //     uint128 menuId,
    //     uint128 quantityToIncrease
    // ) external { 
    //     MenuItem storage item = menuItems[restaurantId][menuId];
    //     if (item.id == 0) revert MenuManager__MenuItemNotFound();
    //     if (quantityToIncrease == 0) return; 

    //     item.quantityAvailable += quantityToIncrease;
    // }

// ------ HÀM VIEW -------------------------

    function getMenuItem(uint128 restaurantId, uint128 menuId) external view override returns (MenuItem memory) {
    MenuItem memory item = menuItems[restaurantId][menuId];

    if (item.id == 0) { 
        if (restaurantMenuItemIds[restaurantId].length == 0 && (nextMenuIds[restaurantId] == 0 || nextMenuIds[restaurantId] == 1) ) {
                revert MenuManager__RestaurantHasNoMenuYet();
            }
        revert MenuManager__MenuItemNotFound();
    }
    return item;
}

    function getMenuItemsByRestaurant(uint128 restaurantId) external view override returns (MenuItem[] memory) {
        uint128[] storage menuItemIdList = restaurantMenuItemIds[restaurantId]; 
        uint256 count = menuItemIdList.length;

        if (count == 0) {
            return new MenuItem[](0); 
        }

        MenuItem[] memory items = new MenuItem[](count);
        for (uint128 i = 0; i < count; i++) {
            uint128 currentMenuId = menuItemIdList[i];

            if (menuItems[restaurantId][currentMenuId].id != 0) {
                items[i] = menuItems[restaurantId][currentMenuId];
            } else {
            }
        }
        return items;
    }

    function getMenuItemIdsByRestaurant(uint128 restaurantId) external view override returns (uint128[] memory) {
        uint128[] storage idsStorage = restaurantMenuItemIds[restaurantId];
        uint128[] memory idsMemory = new uint128[](idsStorage.length);
        for (uint i = 0; i < idsStorage.length; i++) {
            idsMemory[i] = idsStorage[i];
        }
        return idsMemory;
    }

}