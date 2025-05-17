// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

import "../structs/FoodTypes.sol";
contract RoleAccess {
    // enum Role { None, Admin, Customer, FOH, BOH }

    // Error cho RoleAccess
    error RoleAccess__NotAdmin();
    error RoleAccess__AlreadyHasRole(address account, Role role);
    error RoleAccess__NotSpecificRole(address account, Role requiredRole);
    error RoleAccess__InvalidRestaurantId();
    error RoleAccess__NotStaffOfRestaurant(address staff, uint128 restaurantId);
    error RoleAccess__NotFoodApp();

    mapping(address => Role) public roles;
    mapping(address => mapping(uint128 => bool)) public staffAssignments;
    mapping(address => mapping(uint128 => uint128)) public staffAssignmentDates;
    mapping(uint128 => address[]) public staffListByRestaurant; 
    mapping(uint128 => mapping(address => uint)) internal staffIndexInRestaurantList;
    address internal _roleAdmin;

    // address public foodApp;

    event RoleGranted(address indexed account, Role indexed role);
    event RoleRevoked(address indexed account, Role indexed oldRole);
    event StaffAssignedToRestaurant(address indexed staff, uint128 indexed restaurantId);
    event StaffRemovedFromRestaurant(address indexed staff, uint128 indexed restaurantId);

    modifier onlyRoleAdmin() {
        if (msg.sender != _roleAdmin) revert RoleAccess__NotAdmin();
        _;
    }

    function initializeRoles(address adminAddress) internal {
        _roleAdmin = adminAddress;
        roles[adminAddress] = Role.Admin;
        emit RoleGranted(adminAddress, Role.Admin);
    }

    function _grantRoleInternal(address account, Role role) internal {
        roles[account] = role;
        emit RoleGranted(account, role);
    }

    function _revokeRoleInternal(address account) internal {
        Role oldRole = roles[account];
        roles[account] = Role.None;
        emit RoleRevoked(account, oldRole);
    }

    // Hàm này sẽ được gọi bởi admin của FoodApp
    function assignStaffToRestaurant(address staffAccount, uint128 restaurantId, Role staffRole) public onlyRoleAdmin {
        if (staffRole != Role.FOH && staffRole != Role.BOH) {
            revert RoleAccess__NotSpecificRole(staffAccount, staffRole); 
        }
        if (restaurantId == 0) revert RoleAccess__InvalidRestaurantId(); 

        if (roles[staffAccount] == Role.None || (roles[staffAccount] != Role.FOH && roles[staffAccount] != Role.BOH) ) {
            roles[staffAccount] = staffRole; 
            emit RoleGranted(staffAccount, staffRole);
        } else if (roles[staffAccount] != staffRole) {
            roles[staffAccount] = staffRole; 
            emit RoleGranted(staffAccount, staffRole); 
        }
        if (staffIndexInRestaurantList[restaurantId][staffAccount] == 0) { 
        staffListByRestaurant[restaurantId].push(staffAccount);
        staffIndexInRestaurantList[restaurantId][staffAccount] = staffListByRestaurant[restaurantId].length; // Lưu index + 1
    }
        staffAssignments[staffAccount][restaurantId] = true;
        staffAssignmentDates[staffAccount][restaurantId] = uint128(block.timestamp);
        emit StaffAssignedToRestaurant(staffAccount, restaurantId);
    }

    function removeStaffFromRestaurant(address staffAccount, uint128 restaurantId) public onlyRoleAdmin {
        if (!staffAssignments[staffAccount][restaurantId]) {
             revert RoleAccess__NotStaffOfRestaurant(staffAccount, restaurantId);
        }
        uint indexPlusOne = staffIndexInRestaurantList[restaurantId][staffAccount];
    if (indexPlusOne > 0) { 
        uint indexToRemove = indexPlusOne - 1;
        address lastStaff = staffListByRestaurant[restaurantId][staffListByRestaurant[restaurantId].length - 1];

        staffListByRestaurant[restaurantId][indexToRemove] = lastStaff;
        staffIndexInRestaurantList[restaurantId][lastStaff] = indexToRemove + 1;
        staffListByRestaurant[restaurantId].pop();
        staffIndexInRestaurantList[restaurantId][staffAccount] = 0;
    }
        delete staffAssignments[staffAccount][restaurantId];
        delete staffAssignmentDates[staffAccount][restaurantId];
        emit StaffRemovedFromRestaurant(staffAccount, restaurantId);
    }
    function _getStaffAssignmentDateInternal(address staffAccount, uint128 restaurantId) internal view returns (uint128) {
        return staffAssignmentDates[staffAccount][restaurantId];
    }
    function _getStaffAddressesForRestaurantInternal(uint128 _restaurantId) internal view returns (address[] memory) {
        return staffListByRestaurant[_restaurantId];
    }


    function _isStaffOfRestaurant(address account, uint128 restaurantId) internal view returns (bool) {
        if (restaurantId == 0) return false; 
        bool hasStaffRole = (roles[account] == Role.FOH || roles[account] == Role.BOH);
        return hasStaffRole && staffAssignments[account][restaurantId];
    }

    // Modifiers cho FoodApp sử dụng (ví dụ)
    modifier onlyAdmin() {
        if (roles[msg.sender] != Role.Admin) revert RoleAccess__NotSpecificRole(msg.sender, Role.Admin);
        _;
    }

    modifier onlyCustomer() {
        if (roles[msg.sender] != Role.Customer && roles[msg.sender] != Role.Admin && roles[msg.sender] != Role.None) { // Admin cũng có thể là customer
            revert RoleAccess__NotSpecificRole(msg.sender, Role.Customer);
        }
        _;
    }

    // Modifier này cần được định nghĩa trong FoodApp vì nó cần restaurantId từ tham số hàm
    // Hoặc FoodApp gọi _isStaffOfRestaurant trực tiếp.
    // modifier onlyStaffOfSpecificRestaurant(uint128 restaurantId) {
    //     if (!_isStaffOfRestaurant(msg.sender, restaurantId)) revert RoleAccess__NotStaffOfRestaurant(msg.sender, restaurantId);
    //     _;
    // }
}