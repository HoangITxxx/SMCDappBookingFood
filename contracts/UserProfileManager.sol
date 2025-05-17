// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

import "@openzeppelin/contracts-upgradeable/access/OwnableUpgradeable.sol";
import "@openzeppelin/contracts-upgradeable/proxy/utils/Initializable.sol";

import "../interfaces/IUserProfileManager.sol";
import "../structs/FoodTypes.sol"; 

contract UserProfileManager is Initializable, OwnableUpgradeable, IUserProfileManager {
    mapping(address => UserProfile) private _userProfiles;
    address public foodAppContractAddress; 

    error UserProfileManager__InvalidAddress();
    error UserProfileManager__UnauthorizedCaller();
    error UserProfileManager__ProfileNotFound();
    error UserProfileManager__EmptyName();
    error UserProfileManager__AlreadyInitialized(); 
    error UserProfileManager__NotInitializing();   

    // === Modifiers ===
    modifier onlyFoodApp() {
        if (msg.sender != foodAppContractAddress) {
            revert UserProfileManager__UnauthorizedCaller();
        }
        _;
    }

    modifier onlyFoodAppOrOwner() {
        if (msg.sender != foodAppContractAddress && msg.sender != owner()) {
            revert UserProfileManager__UnauthorizedCaller();
        }
        _;
    }

    function initialize(address _foodAppContract, address _initialOwner) public override initializer 
    {
        if (_foodAppContract == address(0) || _initialOwner == address(0)) {
            revert UserProfileManager__InvalidAddress();
        }
        __Ownable_init(_initialOwner);
        foodAppContractAddress = _foodAppContract;
    }

    // === IUserProfileManager Implementation ===

    function createOrUpdateUserProfile(
        address user,
        string calldata name,
        string calldata phoneNumber,
        string calldata email,
        string calldata imageUrl
    ) external override onlyFoodApp { 
        if (user == address(0)) revert UserProfileManager__InvalidAddress();
        if (bytes(name).length == 0) revert UserProfileManager__EmptyName();

        UserProfile storage profile = _userProfiles[user];
        bool isNewProfile = (profile.userAddress == address(0));

        profile.userAddress = user;
        profile.name = name;
        profile.phoneNumber = phoneNumber;
        profile.email = email;
        profile.imageUrl = imageUrl;

        if (isNewProfile) {
            profile.isActive = true; 
            profile.registrationDate = uint128(block.timestamp);
            emit UserProfileCreated(user, name, profile.registrationDate);
        } else {
            emit UserProfileUpdated(user, name);
        }
    }

    function getUserProfile(address user) external view override returns (UserProfile memory profile) {
        if (_userProfiles[user].userAddress == address(0)) {
            revert UserProfileManager__ProfileNotFound();
        }
        return _userProfiles[user];
    }

    function userProfileExists(address user) external view override returns (bool) {
        return _userProfiles[user].userAddress != address(0);
    }

    function activateUserProfile(address user) external override onlyFoodAppOrOwner {
        if (_userProfiles[user].userAddress == address(0)) {
            revert UserProfileManager__ProfileNotFound();
        }
        UserProfile storage profile = _userProfiles[user];
        if (!profile.isActive) {
            profile.isActive = true;
            emit UserProfileActivityChanged(user, true);
        }
    }

    function deactivateUserProfile(address user) external override onlyFoodAppOrOwner {
        if (_userProfiles[user].userAddress == address(0)) {
            revert UserProfileManager__ProfileNotFound();
        }
        UserProfile storage profile = _userProfiles[user];
        if (profile.isActive) {
            profile.isActive = false;
            emit UserProfileActivityChanged(user, false);
        }
    }

    // function updateSpecificProfileFields(...) external override onlyFoodApp { ... } // Implement if needed

    // --- Versioning for upgradeability (optional but good practice) ---
    // function version() external pure returns (string memory) {
    //     return "1.0.0";
    // }
}