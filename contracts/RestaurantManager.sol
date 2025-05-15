// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

import "@openzeppelin/contracts-upgradeable/access/OwnableUpgradeable.sol";
import "../structs/FoodTypes.sol";
import "../interfaces/IRestaurantManager.sol";

contract RestaurantManager is OwnableUpgradeable, IRestaurantManager {
    uint128 public nextRestaurantId;
    mapping(uint128 => Restaurant) public restaurants; 
    mapping(address => uint128[]) public restaurantsByOwner;

    address public foodAppContractAddress;

    event RestaurantRegistered(uint128 indexed restaurantId, address indexed owner, string name);

    error RestaurantManager__NotFoodApp();
    error RestaurantManager__InvalidAddress();
    error RestaurantManager__RestaurantNotFound();

    modifier onlyFoodAppContract() {
        if (msg.sender != foodAppContractAddress) revert RestaurantManager__NotFoodApp();
        _;
    }

    function initialize(address _foodAppContract, address _factoryOwner) public initializer {
        if (_foodAppContract == address(0)) revert RestaurantManager__InvalidAddress();
        // _factoryOwner cũng không nên là address(0) nếu nó là owner
        if (_factoryOwner == address(0)) revert RestaurantManager__InvalidAddress();
        __Ownable_init(_factoryOwner); // FoodAppFactory là owner
        foodAppContractAddress = _foodAppContract;
        nextRestaurantId = 1;
    }

    // restaurantActualOwner là EOA được FoodApp xác thực và truyền vào
    function registerRestaurant(address restaurantActualOwner) external override onlyFoodAppContract returns (uint128) {
        if (restaurantActualOwner == address(0)) revert RestaurantManager__InvalidAddress();

        uint128 restaurantId = nextRestaurantId;
        restaurants[restaurantId] = Restaurant({
            id: restaurantId,
            owner: restaurantActualOwner,
            name: "" // FoodApp sẽ gọi hàm khác để cập nhật tên/chi tiết
        });
        restaurantsByOwner[restaurantActualOwner].push(restaurantId);

        emit RestaurantRegistered(restaurantId, restaurantActualOwner, "");
        nextRestaurantId++;
        return restaurantId;
    }

    function restaurantExists(uint128 restaurantId) external view override returns (bool) {
        return restaurants[restaurantId].id != 0;
    }

    function getRestaurantOwner(uint128 restaurantId) external view override returns (address) {
        if (restaurants[restaurantId].id == 0) revert RestaurantManager__RestaurantNotFound();
        return restaurants[restaurantId].owner;
    }

    // Thêm các hàm để cập nhật thông tin nhà hàng (tên, địa điểm,...)
    // function updateRestaurantName(uint128 restaurantId, string memory newName) external onlyFoodAppContract { ... }
}