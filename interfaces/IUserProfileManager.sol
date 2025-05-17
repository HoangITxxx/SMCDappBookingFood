// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

import "../structs/FoodTypes.sol"; // Để dùng UserProfile struct

interface IUserProfileManager {
    event UserProfileCreated(address indexed user, string name, uint128 registrationDate);
    event UserProfileUpdated(address indexed user, string name);
    event UserProfileActivityChanged(address indexed user, bool isActive);
    
    function initialize(address _foodAppContract, address _initialOwner) external;
    function createOrUpdateUserProfile(
        address user,
        string calldata name,
        string calldata phoneNumber,
        string calldata email,
        string calldata imageUrl
    ) external;

    function getUserProfile(address user) external view returns (UserProfile memory profile);

    function userProfileExists(address user) external view returns (bool);

    function activateUserProfile(address user) external;

    function deactivateUserProfile(address user) external;

    // Có thể có các hàm admin khác nếu cần, ví dụ:
    // function adminUpdateUserProfile(address userAddr, bytes32 displayName, ...) external onlyOwner;
}