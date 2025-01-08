
// SPDX-License-Identifier: MIT
pragma solidity 0.8.18;

/*
 * @author not-so-secure-dev
 * @title PasswordStore
 * @notice This contract allows you to store a private hashed password. Only the owner can update or view the password.
 */
contract PasswordStore {
    error PasswordStore__NotOwner();

    address private s_owner;
    bytes32 private s_password;

    event PasswordUpdated(address indexed owner, bytes32 passwordHash);

    constructor() {
        s_owner = msg.sender;
    }

    /*
     * @notice Allows only the owner to set a new hashed password.
     * @param newPassword The new password to hash and store.
     */
    function setPassword(string memory newPassword) external {
        if (msg.sender != s_owner) {
            revert PasswordStore__NotOwner();
        }
        s_password = keccak256(abi.encodePacked(newPassword));
        emit PasswordUpdated(msg.sender, s_password);
    }

    /*
     * @notice Allows only the owner to retrieve the hashed password.
     * @return The hashed password.
     */
    function getPassword() external view returns (bytes32) {
        if (msg.sender != s_owner) {
            revert PasswordStore__NotOwner();
        }
        return s_password;
    }

    /*
     * @notice Allows the owner to transfer ownership of the contract.
     * @param newOwner The address of the new owner.
     */
    function transferOwnership(address newOwner) external {
        if (msg.sender != s_owner) {
            revert PasswordStore__NotOwner();
        }
        s_owner = newOwner;
    }
}
