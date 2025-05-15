// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

contract RoleAccess {
    enum Role { None, Admin, Customer, FOH, BOH }

    // Error cho RoleAccess
    error RoleAccess__NotAdmin();
    error RoleAccess__AlreadyHasRole(address account, Role role);
    error RoleAccess__NotSpecificRole(address account, Role requiredRole);
    error RoleAccess__InvalidRestaurantId();
    error RoleAccess__NotStaffOfRestaurant(address staff, uint128 restaurantId);

    mapping(address => Role) public roles;
    mapping(address => mapping(uint128 => bool)) public staffAssignments;
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
        // Hàm này được gọi trong initialize của contract kế thừa (ví dụ FoodApp)
        // adminAddress (ví dụ: chủ của FoodApp) sẽ có quyền quản lý vai trò trong FoodApp đó.
        _roleAdmin = adminAddress;
        roles[adminAddress] = Role.Admin;
        emit RoleGranted(adminAddress, Role.Admin);
    }

    function grantRole(address account, Role role) public onlyRoleAdmin {
        // if (roles[account] != Role.None) revert RoleAccess__AlreadyHasRole(account, roles[account]); // Có thể muốn cho phép thay đổi vai trò
        roles[account] = role;
        emit RoleGranted(account, role);
    }

    function revokeRole(address account) public onlyRoleAdmin {
        Role oldRole = roles[account];
        roles[account] = Role.None;
        // Nếu là staff, cũng cần xóa khỏi các nhà hàng
        // Điều này cần logic phức tạp hơn nếu staffAssignments là mapping(address => mapping(uint128 => bool))
        // Ví dụ đơn giản: nếu bạn có staffPrimaryRestaurant, thì xóa nó.
        emit RoleRevoked(account, oldRole);
    }

    // Hàm này sẽ được gọi bởi admin của FoodApp
    function assignStaffToRestaurant(address staffAccount, uint128 restaurantId, Role staffRole) public onlyRoleAdmin {
        if (staffRole != Role.FOH && staffRole != Role.BOH) {
            revert RoleAccess__NotSpecificRole(staffAccount, staffRole); 
        }
        if (restaurantId == 0) revert RoleAccess__InvalidRestaurantId(); // FoodApp nên check restaurant tồn tại

        if (roles[staffAccount] == Role.None || (roles[staffAccount] != Role.FOH && roles[staffAccount] != Role.BOH) ) {
            roles[staffAccount] = staffRole; 
            emit RoleGranted(staffAccount, staffRole);
        } else if (roles[staffAccount] != staffRole) {
            roles[staffAccount] = staffRole; 
            emit RoleGranted(staffAccount, staffRole); 
        }


        staffAssignments[staffAccount][restaurantId] = true;
        emit StaffAssignedToRestaurant(staffAccount, restaurantId);
    }

    function removeStaffFromRestaurant(address staffAccount, uint128 restaurantId) public onlyRoleAdmin {
        // if (restaurantId == 0) revert RoleAccess__InvalidRestaurantId();
        if (!staffAssignments[staffAccount][restaurantId]) {
             revert RoleAccess__NotStaffOfRestaurant(staffAccount, restaurantId);
        }
        delete staffAssignments[staffAccount][restaurantId];
        emit StaffRemovedFromRestaurant(staffAccount, restaurantId);
        // Cân nhắc: có nên revoke vai trò chung của staff nếu họ không còn được gán cho nhà hàng nào không?
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
        if (roles[msg.sender] != Role.Customer && roles[msg.sender] != Role.Admin) { // Admin cũng có thể là customer
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