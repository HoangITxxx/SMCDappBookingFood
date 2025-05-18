// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

import "../interfaces/IRestaurantManager.sol";
import "../interfaces/IMenuManager.sol";
import "../interfaces/IOrderManager.sol";
import "../interfaces/IReviewManager.sol";
import "../interfaces/IUserProfileManager.sol";
import "../interfaces/ITableManager.sol"; 
import "../interfaces/ICategoriesManager.sol";

library ProxyLib {
    function deployMinimalProxy(address implementation) internal returns (address proxy) {
        bytes memory code = abi.encodePacked(
            hex"3d602d80600a3d3981f3363d3d373d3d3d363d73",
            implementation,
            hex"5af43d82803e903d91602b57fd5bf3"
        );
        assembly {
            proxy := create(0, add(code, 0x20), mload(code))
        }
        require(proxy != address(0), "Deployment failed");
    }
}

contract FoodAppFactory {
    address public admin;
    mapping(bytes32 => address) public implementations;
    mapping(address => mapping(string => address)) public managers;
    mapping(address => bool) public isFoodApp;

    event ManagerDeployed(address indexed foodApp, string indexed managerType, address manager);
    event FoodAppRegistered(address indexed foodApp);
    event ImplementationSet(bytes32 indexed managerTypeHash, address indexed implementationAddress);

    error FoodAppFactory__OnlyAdmin();
    error FoodAppFactory__InvalidAddress();
    error FoodAppFactory__AlreadyRegistered();
    error FoodAppFactory__NotRegisteredFoodApp();
    error FoodAppFactory__ManagerAlreadyDeployed();
    error FoodAppFactory__ImplementationNotSet();
    error FoodAppFactory__DependencyNotDeployed(string dependency);
    error FoodAppFactory__UnknownManagerType();


    constructor() {
        admin = msg.sender;
    }

    modifier onlyAdmin() {
        if (msg.sender != admin) revert FoodAppFactory__OnlyAdmin();
        _;
    }

    function setImplementation(string calldata managerType, address implementationAddress) external onlyAdmin {
        if (implementationAddress == address(0)) revert FoodAppFactory__InvalidAddress();
        bytes32 typeHash = keccak256(abi.encodePacked(managerType));
        implementations[typeHash] = implementationAddress;
        emit ImplementationSet(typeHash, implementationAddress);
    }

    function registerFoodApp(address _foodApp) external onlyAdmin {
        if (_foodApp == address(0)) revert FoodAppFactory__InvalidAddress();
        if (isFoodApp[_foodApp]) revert FoodAppFactory__AlreadyRegistered();
        isFoodApp[_foodApp] = true;
        emit FoodAppRegistered(_foodApp);
    }

    function deployManager(string calldata managerType) external returns (address) {
        address foodAppContract = msg.sender;
        if (!isFoodApp[foodAppContract]) revert FoodAppFactory__NotRegisteredFoodApp();

        bytes32 typeHash = keccak256(abi.encodePacked(managerType));
        if (managers[foodAppContract][managerType] != address(0)) revert FoodAppFactory__ManagerAlreadyDeployed();

        address implementation = implementations[typeHash];
        if (implementation == address(0)) revert FoodAppFactory__ImplementationNotSet();

        address managerProxy = ProxyLib.deployMinimalProxy(implementation);
        address factoryOwner = address(this); // Factory contract sẽ là owner của các manager proxy

        if (typeHash == keccak256("RestaurantManager")) {
            IRestaurantManager(managerProxy).initialize(foodAppContract, factoryOwner);
        } else if (typeHash == keccak256("CategoriesManager")) { 
            address restaurantManagerAddress = managers[foodAppContract]["RestaurantManager"];
            if (restaurantManagerAddress == address(0)) revert FoodAppFactory__DependencyNotDeployed("RestaurantManager for CategoriesManager");
            ICategoriesManager(managerProxy).initialize(foodAppContract, restaurantManagerAddress, factoryOwner);
        } else if (typeHash == keccak256("MenuManager")) {
            address restaurantManagerAddress = managers[foodAppContract]["RestaurantManager"];
            address categoriesManagerAddress = managers[foodAppContract]["CategoriesManager"];
            if (restaurantManagerAddress == address(0)) revert FoodAppFactory__DependencyNotDeployed("RestaurantManager for MenuManager");
            if (categoriesManagerAddress == address(0)) revert FoodAppFactory__DependencyNotDeployed("CategoriesManager for MenuManager");
            IMenuManager(managerProxy).initialize(foodAppContract, categoriesManagerAddress , restaurantManagerAddress , factoryOwner);
        } else if (typeHash == keccak256("TableManager")) { 
            address restaurantManagerAddress = managers[foodAppContract]["RestaurantManager"];
            if (restaurantManagerAddress == address(0)) revert FoodAppFactory__DependencyNotDeployed("RestaurantManager for TableManager");
            ITableManager(managerProxy).initialize(foodAppContract, restaurantManagerAddress, factoryOwner);
        } else if (typeHash == keccak256("OrderManager")) {
            address menuManagerAddress = managers[foodAppContract]["MenuManager"];
            address restaurantManagerAddress = managers[foodAppContract]["RestaurantManager"];
            address tableManagerAddress = managers[foodAppContract]["TableManager"];
            if (menuManagerAddress == address(0)) revert FoodAppFactory__DependencyNotDeployed("MenuManager");
            if (restaurantManagerAddress == address(0)) revert FoodAppFactory__DependencyNotDeployed("RestaurantManager");
            IOrderManager(managerProxy).initialize(foodAppContract, menuManagerAddress, restaurantManagerAddress, tableManagerAddress, factoryOwner);
        } else if (typeHash == keccak256("ReviewManager")) {
            address restaurantManagerAddress = managers[foodAppContract]["RestaurantManager"];
            address menuManagerAddress = managers[foodAppContract]["MenuManager"];
            if (restaurantManagerAddress == address(0)) revert FoodAppFactory__DependencyNotDeployed("RestaurantManager");
            if (menuManagerAddress == address(0)) revert FoodAppFactory__DependencyNotDeployed("MenuManager");
            IReviewManager(managerProxy).initialize(foodAppContract, restaurantManagerAddress, menuManagerAddress, factoryOwner);
        } else if (typeHash == keccak256(abi.encodePacked("UserProfileManager"))) { 
            IUserProfileManager(managerProxy).initialize(foodAppContract, factoryOwner);
        } else {
            revert FoodAppFactory__UnknownManagerType();
        }

        managers[foodAppContract][managerType] = managerProxy;
        emit ManagerDeployed(foodAppContract, managerType, managerProxy);
        return managerProxy;
    }

    function getManager(address foodApp, string calldata managerType) external view returns (address) {
        return managers[foodApp][managerType];
    }
}