// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

import "../structs/FoodTypes.sol";

interface ITableManager {
    function initialize( address _foodAppContract, address _restaurantManagerAddress, address _factoryOwner ) external;

    function addTable(uint128 _restaurantId, string memory _tableNumber) external returns (uint128);
    function updateTable(uint128 _tableId, string memory _newTableNumber, bool _isActive) external;
    function getTable(uint128 _tableId) external view returns (Table memory);
    function getTablesByRestaurant(uint128 _restaurantId) external view returns (Table[] memory);
    function tableExists(uint128 _restaurantId, string memory _tableNumber) external view returns (bool);
    function getTableIdByRestaurantAndNumber(uint128 _restaurantId, string memory _tableNumber) external view returns (uint128);
}