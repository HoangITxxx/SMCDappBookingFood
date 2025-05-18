// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

import "@openzeppelin/contracts-upgradeable/access/OwnableUpgradeable.sol";
import "../structs/FoodTypes.sol";
import "../interfaces/ICategoriesManager.sol";
import "../interfaces/IRestaurantManager.sol";

contract CategoriesManager is OwnableUpgradeable, ICategoriesManager {
    uint128 public nextCategoryId;
    mapping(uint128 => Category) public categoriesById; 
    mapping(uint128 => uint128[]) internal categoryIdsByRestaurant; 

    mapping(uint128 => mapping(bytes32 => uint128)) internal categoryIdByRestaurantAndNameHash;

    address public foodAppContractAddress;
    IRestaurantManager public restaurantManager;

    error CategoriesManager__NotFoodApp();
    error CategoriesManager__InvalidAddress();
    error CategoriesManager__RestaurantNotFound(uint128 restaurantId);
    error CategoriesManager__CategoryNotFound(uint128 categoryId);
    error CategoriesManager__CategoryNameAlreadyExists(uint128 restaurantId, string name);
    error CategoriesManager__InvalidCategoryName();
    error CategoriesManager__CategoryNotBelongToRestaurant(uint128 categoryId, uint128 restaurantId);

    modifier onlyFoodAppContract() {
        if (msg.sender != foodAppContractAddress) revert CategoriesManager__NotFoodApp();
        _;
    }

    function initialize(
        address _foodAppContract,
        address _restaurantManagerAddress,
        address _factoryOwner
    ) public override initializer {
        if (_foodAppContract == address(0)) revert CategoriesManager__InvalidAddress();
        if (_restaurantManagerAddress == address(0)) revert CategoriesManager__InvalidAddress(); 
        __Ownable_init(_factoryOwner);
        foodAppContractAddress = _foodAppContract;
        restaurantManager = IRestaurantManager(_restaurantManagerAddress);
        nextCategoryId = 1;
    }

    function addRestaurantCategory(
        uint128 _restaurantId,
        string memory _name,
        string memory _description
    ) external override onlyFoodAppContract returns (uint128 categoryId) {
        if (!restaurantManager.restaurantExists(_restaurantId)) revert CategoriesManager__RestaurantNotFound(_restaurantId);
        if (bytes(_name).length == 0) revert CategoriesManager__InvalidCategoryName();

        bytes32 nameHash = keccak256(abi.encodePacked(_name));
        if (categoryIdByRestaurantAndNameHash[_restaurantId][nameHash] != 0) {
            revert CategoriesManager__CategoryNameAlreadyExists(_restaurantId, _name);
        }

        categoryId = nextCategoryId;
        categoriesById[categoryId] = Category({
            id: categoryId,
            restaurantId: _restaurantId,
            name: _name,
            description: _description,
            isActive: true
        });
        categoryIdsByRestaurant[_restaurantId].push(categoryId);
        categoryIdByRestaurantAndNameHash[_restaurantId][nameHash] = categoryId;

        emit CategoryAdded(categoryId, _restaurantId, _name);
        nextCategoryId++;
        return categoryId;
    }

    function updateRestaurantCategory(
        uint128 _categoryId,
        string memory _newName,
        string memory _newDescription,
        bool _isActive
    ) external override onlyFoodAppContract {
        Category storage categoryToUpdate = categoriesById[_categoryId];
        if (categoryToUpdate.id == 0) revert CategoriesManager__CategoryNotFound(_categoryId);

        if (bytes(_newName).length == 0) revert CategoriesManager__InvalidCategoryName();
        if (keccak256(abi.encodePacked(categoryToUpdate.name)) != keccak256(abi.encodePacked(_newName))) {
            bytes32 oldNameHash = keccak256(abi.encodePacked(categoryToUpdate.name));
            bytes32 newNameHash = keccak256(abi.encodePacked(_newName));
            if (categoryIdByRestaurantAndNameHash[categoryToUpdate.restaurantId][newNameHash] != 0) {
                revert CategoriesManager__CategoryNameAlreadyExists(categoryToUpdate.restaurantId, _newName);
            }
            delete categoryIdByRestaurantAndNameHash[categoryToUpdate.restaurantId][oldNameHash];
            categoryIdByRestaurantAndNameHash[categoryToUpdate.restaurantId][newNameHash] = _categoryId;
            categoryToUpdate.name = _newName;
        }

        categoryToUpdate.description = _newDescription;
        categoryToUpdate.isActive = _isActive;
        emit CategoryUpdated(_categoryId, _newName, _newDescription, _isActive);
    }

    function getCategoryById(uint128 _categoryId) external view override returns (Category memory) {
        Category memory category = categoriesById[_categoryId];
        if (category.id == 0) revert CategoriesManager__CategoryNotFound(_categoryId);
        return category;
    }

    function getCategoriesByRestaurant(uint128 _restaurantId) external view override returns (Category[] memory) {
        uint128[] storage ids = categoryIdsByRestaurant[_restaurantId];
        Category[] memory restaurantCategories = new Category[](ids.length);
        for (uint i = 0; i < ids.length; i++) {
            restaurantCategories[i] = categoriesById[ids[i]];
        }
        return restaurantCategories;
    }

    function categoryExists(uint128 _restaurantId, uint128 _categoryId) external view override returns (bool) {
        Category memory category = categoriesById[_categoryId];
        return category.id != 0 && category.restaurantId == _restaurantId && category.isActive;
    }

    function getCategoryByName(uint128 _restaurantId, string memory _name) external view override returns (Category memory) {
        if (bytes(_name).length == 0) revert CategoriesManager__InvalidCategoryName();
        bytes32 nameHash = keccak256(abi.encodePacked(_name));
        uint128 categoryId = categoryIdByRestaurantAndNameHash[_restaurantId][nameHash];
        if (categoryId == 0) revert CategoriesManager__CategoryNotFound(0); 
        return categoriesById[categoryId];
    }
}