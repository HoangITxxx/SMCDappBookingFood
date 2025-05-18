// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

import "../structs/FoodTypes.sol";

interface ICategoriesManager {
    event CategoryAdded(uint128 indexed categoryId, uint128 indexed restaurantId, string name);
    event CategoryUpdated(uint128 indexed categoryId, string newName, string newDescription, bool newIsActive);

    function initialize(
        address _foodAppContract,
        address _restaurantManagerAddress,
        address _factoryOwner
    ) external;

    function addRestaurantCategory(uint128 _restaurantId, string memory _name, string memory _description) external returns (uint128 categoryId);
    function updateRestaurantCategory(uint128 _categoryId, string memory _newName, string memory _newDescription, bool _isActive) external;
    function getCategoryById(uint128 _categoryId) external view returns (Category memory);
    function getCategoriesByRestaurant(uint128 _restaurantId) external view returns (Category[] memory);
    function categoryExists(uint128 _restaurantId, uint128 _categoryId) external view returns (bool); 
    function getCategoryByName(uint128 _restaurantId, string memory _name) external view returns (Category memory); 

}