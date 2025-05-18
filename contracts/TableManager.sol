// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

import "@openzeppelin/contracts-upgradeable/access/OwnableUpgradeable.sol";
import "../structs/FoodTypes.sol";
import "../interfaces/ITableManager.sol";
import "../interfaces/IRestaurantManager.sol";

contract TableManager is OwnableUpgradeable, ITableManager {
    uint128 public nextTableId;
    mapping(uint128 => Table) public tablesById;
    mapping(uint128 => uint128[]) internal tablesByRestaurantId; 
    mapping(uint128 => mapping(bytes32 => uint128)) internal tableIdByRestaurantAndNumberHash;

    address public foodAppContractAddress;
    IRestaurantManager public restaurantManager;

    event TableAdded(uint128 indexed tableId, uint128 indexed restaurantId, string tableNumber);
    event TableUpdated(uint128 indexed tableId, string newTableNumber, bool newIsActive);

    error TableManager__NotFoodApp();
    error TableManager__InvalidAddress();
    error TableManager__RestaurantNotFound(uint128 restaurantId);
    error TableManager__TableNotFound(uint128 tableId);
    error TableManager__TableNumberAlreadyExists(uint128 restaurantId, string tableNumber);
    error TableManager__InvalidTableNumber();

    modifier onlyFoodAppContract() {
        if (msg.sender != foodAppContractAddress) revert TableManager__NotFoodApp();
        _;
    }

    function initialize(address _foodAppContract, address _restaurantManagerAddress, address _factoryOwner) public initializer {
        if (_foodAppContract == address(0)) revert TableManager__InvalidAddress();
        if (_restaurantManagerAddress == address(0)) revert TableManager__InvalidAddress();
        __Ownable_init(_factoryOwner);
        foodAppContractAddress = _foodAppContract;
        restaurantManager = IRestaurantManager(_restaurantManagerAddress);
        nextTableId = 1;
    }

    function addTable(
        uint128 _restaurantId,
        string memory _tableNumber
    ) external override onlyFoodAppContract returns (uint128) {
        if (!restaurantManager.restaurantExists(_restaurantId)) revert TableManager__RestaurantNotFound(_restaurantId);
        if (bytes(_tableNumber).length == 0) revert TableManager__InvalidTableNumber();

        bytes32 tableNumberHash = keccak256(abi.encodePacked(_tableNumber));
        if (tableIdByRestaurantAndNumberHash[_restaurantId][tableNumberHash] != 0) {
            revert TableManager__TableNumberAlreadyExists(_restaurantId, _tableNumber);
        }

        uint128 currentTableId = nextTableId;
        tablesById[currentTableId] = Table({
            id: currentTableId,
            restaurantId: _restaurantId,
            tableNumber: _tableNumber,
            isActive: true
        });
        tablesByRestaurantId[_restaurantId].push(currentTableId);
        tableIdByRestaurantAndNumberHash[_restaurantId][tableNumberHash] = currentTableId;

        emit TableAdded(currentTableId, _restaurantId, _tableNumber);
        nextTableId++;
        return currentTableId;
    }

    function updateTable(
        uint128 _tableId,
        string memory _newTableNumber,
        bool _isActive
    ) external override onlyFoodAppContract {
        Table storage tableToUpdate = tablesById[_tableId];
        if (tableToUpdate.id == 0) revert TableManager__TableNotFound(_tableId);
        if (bytes(_newTableNumber).length == 0) revert TableManager__InvalidTableNumber();

        // Nếu số bàn thay đổi, cần cập nhật mapping tableIdByRestaurantAndNumberHash
        if (keccak256(abi.encodePacked(tableToUpdate.tableNumber)) != keccak256(abi.encodePacked(_newTableNumber))) {
            bytes32 oldTableNumberHash = keccak256(abi.encodePacked(tableToUpdate.tableNumber));
            bytes32 newTableNumberHash = keccak256(abi.encodePacked(_newTableNumber));

            if (tableIdByRestaurantAndNumberHash[tableToUpdate.restaurantId][newTableNumberHash] != 0) {
                revert TableManager__TableNumberAlreadyExists(tableToUpdate.restaurantId, _newTableNumber);
            }
            delete tableIdByRestaurantAndNumberHash[tableToUpdate.restaurantId][oldTableNumberHash];
            tableIdByRestaurantAndNumberHash[tableToUpdate.restaurantId][newTableNumberHash] = _tableId;
            tableToUpdate.tableNumber = _newTableNumber;
        }

        tableToUpdate.isActive = _isActive;

        emit TableUpdated(_tableId, _newTableNumber, _isActive);
    }

    function getTable(uint128 _tableId) external view override returns (Table memory) {
        Table memory table = tablesById[_tableId];
        if (table.id == 0) revert TableManager__TableNotFound(_tableId);
        return table;
    }

    function getTablesByRestaurant(uint128 _restaurantId) external view override returns (Table[] memory) {
        uint128[] storage tableIds = tablesByRestaurantId[_restaurantId];
        Table[] memory restaurantTables = new Table[](tableIds.length);
        for (uint i = 0; i < tableIds.length; i++) {
            restaurantTables[i] = tablesById[tableIds[i]];
        }
        return restaurantTables;
    }

    function tableExists(uint128 _restaurantId, string memory _tableNumber) external view override returns (bool) {
        if (bytes(_tableNumber).length == 0) return false; // Số bàn trống không được coi là tồn tại
        bytes32 tableNumberHash = keccak256(abi.encodePacked(_tableNumber));
        uint128 tableId = tableIdByRestaurantAndNumberHash[_restaurantId][tableNumberHash];
        return tableId != 0 && tablesById[tableId].isActive; // Chỉ coi là tồn tại nếu bàn active
    }

    function getTableIdByRestaurantAndNumber(uint128 _restaurantId, string memory _tableNumber) external view override returns (uint128) {
        if (bytes(_tableNumber).length == 0) revert TableManager__InvalidTableNumber();
        bytes32 tableNumberHash = keccak256(abi.encodePacked(_tableNumber));
        uint128 tableId = tableIdByRestaurantAndNumberHash[_restaurantId][tableNumberHash];
        if (tableId == 0 || !tablesById[tableId].isActive) revert TableManager__TableNotFound(0); // Hoặc một ID không hợp lệ
        return tableId;
    }

    // Hàm để FoodApp set lại địa chỉ các manager khác nếu cần sau khi deploy
    function setRestaurantManagerAddress(address _newAddress) external onlyOwner {
        if (_newAddress == address(0)) revert TableManager__InvalidAddress();
        restaurantManager = IRestaurantManager(_newAddress);
    }
}