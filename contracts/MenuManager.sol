// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

import "@openzeppelin/contracts-upgradeable/access/OwnableUpgradeable.sol";
import "../structs/FoodTypes.sol";
import "../interfaces/IMenuManager.sol";

contract MenuManager is OwnableUpgradeable, IMenuManager {
    mapping(uint128 => mapping(uint128 => MenuItem)) public menuItems;
    mapping(uint128 => uint128) public nextMenuIds; // ID cho món ăn tiếp theo của mỗi nhà hàng

    address public foodAppContractAddress; // Địa chỉ của FoodApp contract quản lý Manager này

    event MenuItemAdded(uint128 indexed restaurantId, uint128 indexed menuId, string name, uint128 price);
    event MenuItemUpdated(uint128 indexed restaurantId, uint128 indexed menuId, string name, uint128 price, bool available);
    event MenuItemRemoved(uint128 indexed restaurantId, uint128 indexed menuId);

    error MenuManager__NotFoodApp();
    error MenuManager__InvalidAddress();
    error MenuManager__NameRequired();
    error MenuManager__InvalidPrice();
    error MenuManager__MenuItemNotFound();
    error MenuManager__RestaurantHasNoMenuYet();


    modifier onlyFoodAppContract() {
        if (msg.sender != foodAppContractAddress) revert MenuManager__NotFoodApp();
        _;
    }


    function initialize(address _foodAppContract, address _factoryOwner) public initializer {
        if (_foodAppContract == address(0)) revert MenuManager__InvalidAddress(); 
        __Ownable_init(_factoryOwner);
        foodAppContractAddress = _foodAppContract;
    }


    function addMenuItem(
        uint128 restaurantId,
        string memory name,
        string memory menuTitle,
        uint128 price,
        string memory description,
        string memory category,
        uint128 preparationTime
    ) external override onlyFoodAppContract {
        if (bytes(name).length == 0) revert MenuManager__NameRequired();
        if (price == 0) revert MenuManager__InvalidPrice(); 

        if (nextMenuIds[restaurantId] == 0) { 
            nextMenuIds[restaurantId] = 1;
        }
        uint128 menuId = nextMenuIds[restaurantId];
        nextMenuIds[restaurantId]++;

        menuItems[restaurantId][menuId] = MenuItem({
            id: menuId,
            restaurantId: restaurantId,
            name: name,
            menuTitle: menuTitle,
            price: price,
            available: true,
            description: description,
            category: category,
            totalRating: 0,
            ratingCount: 0,
            preparationTime: preparationTime
        });

        emit MenuItemAdded(restaurantId, menuId, name, price);
    }

    function updateMenuItem(
        uint128 restaurantId,
        uint128 menuId,
        string memory name,
        string memory menuTitle,
        uint128 price,
        bool available,
        string memory description,
        string memory category,
        uint128 preparationTime
    ) external override onlyFoodAppContract {
        MenuItem storage itemToUpdate = menuItems[restaurantId][menuId];
        if (itemToUpdate.id == 0) revert MenuManager__MenuItemNotFound();

        if (bytes(name).length == 0) revert MenuManager__NameRequired();
        if (price == 0) revert MenuManager__InvalidPrice();

        itemToUpdate.name = name;
        itemToUpdate.menuTitle = menuTitle;
        itemToUpdate.price = price;
        itemToUpdate.available = available;
        itemToUpdate.description = description;
        itemToUpdate.category = category;
        itemToUpdate.preparationTime = preparationTime;

        emit MenuItemUpdated(restaurantId, menuId, name, price, available);
    }

    function removeMenuItem(
        uint128 restaurantId,
        uint128 menuId
    ) external override onlyFoodAppContract {
        if (menuItems[restaurantId][menuId].id == 0) revert MenuManager__MenuItemNotFound();
        delete menuItems[restaurantId][menuId];
        emit MenuItemRemoved(restaurantId, menuId);
    }

    function getMenuItem(uint128 restaurantId, uint128 menuId) external view override returns (MenuItem memory) {
        MenuItem memory item = menuItems[restaurantId][menuId];

        if (item.id == 0) {
            if (nextMenuIds[restaurantId] == 0) revert MenuManager__RestaurantHasNoMenuYet();
            revert MenuManager__MenuItemNotFound();
        }
        return item;
    }

    // Thêm các hàm view khác nếu cần, ví dụ:
    // function getMenuItemsByRestaurant(uint128 restaurantId) external view returns (MenuItem[] memory) { ... }

}