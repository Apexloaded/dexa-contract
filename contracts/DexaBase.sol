// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import "@openzeppelin/contracts-upgradeable/access/AccessControlUpgradeable.sol";
import "@openzeppelin/contracts-upgradeable/proxy/utils/Initializable.sol";

enum TransactionType {
    Remint,
    Tip,
    Deposit,
    Transfer
}

struct Transaction {
    uint txId;
    TransactionType txType;
    address payable txFrom;
    address payable txTo;
    uint256 txAmount;
    uint256 txFee;
    uint256 txDate;
}

contract DexaBase is Initializable, AccessControlUpgradeable {
    event TokenAdded(address indexed tokenAddress);

    /**
     * @notice Roles Variable
     */
    bytes32 public constant CREATOR_ROLE = keccak256("CREATOR_ROLE");
    bytes32 public constant DEXA_FEEDS_ROLE = keccak256("FEEDS_ROLE");
    bytes32 public constant DEXA_CREATOR_ROLE = keccak256("CREATOR_ROLE");
    bytes32 public constant DEXA_STORAGE_ROLE = keccak256("STORAGE_ROLE");
    bytes32 public constant DEXA_MESSENGER_ROLE = keccak256("MESSENGER_ROLE");

    /**
     * @notice Error Codes
     */
    string public constant ERROR_INVALID_STRING = "0";
    string public constant ERROR_UNAUTHORISED_ACCESS = "1";
    string public constant ERROR_DUPLICATE_RESOURCE = "2";
    string public constant ERROR_NOT_FOUND = "3";
    string public constant ERROR_INVALID_PRICE = "4";
    string public constant ERROR_PROCESS_FAILED = "5";

    /**
     * @notice Dexa Contract Variables
     */
    uint256 public feeRate; // Dexa transaction fee
    address public owner;
    mapping(address => bool) public _allowedTokens; // Tokens allowed for tipping

    modifier onlyAllowedToken(address tokenAddress) {
        if (tokenAddress != address(0)) {
            require(
                _allowedTokens[tokenAddress] == true,
                string.concat("Dexa: ", ERROR_NOT_FOUND)
            );
        }
        _;
    }

    /**
     * @notice Initialize function
     * @param _admin The address of the administrator
     */
    function init_dexa_base(address _admin) public onlyInitializing {
        __AccessControl_init();
        _grantRole(DEFAULT_ADMIN_ROLE, _admin);
        owner = _admin;
    }

    /*************************************************
     * @notice Charge transaction fee
     *************************************************/
    function chargefee(uint256 _amount) internal view returns (uint256) {
        uint256 mintCharge = (_amount * feeRate) / 1000;
        // uint256 charge = _amount - mintCharge;
        // (bool success, ) = address(owner).call{value: charge}("");
        // require(success, string.concat("Dexa: ", ERROR_PROCESS_FAILED));
        return mintCharge;
    }

    function setAdminFee(uint256 _feeRate) public onlyRole(DEFAULT_ADMIN_ROLE) {
        feeRate = _feeRate;
    }

    function addTokenToWhitelist(
        address[] memory tokenAddress
    ) public onlyRole(DEFAULT_ADMIN_ROLE) {
        for (uint256 i = 0; i < tokenAddress.length; i++) {
            _allowedTokens[tokenAddress[i]] = true;
            emit TokenAdded(tokenAddress[i]);
        }
    }

    function toLower(string memory str) internal pure returns (string memory) {
        bytes memory data = bytes(str);
        bytes memory lowercaseData = new bytes(data.length);

        for (uint256 i = 0; i < data.length; i++) {
            lowercaseData[i] = _toLower(data[i]);
        }
        return string(lowercaseData);
    }

    function _toLower(bytes1 char) private pure returns (bytes1) {
        if (uint8(char) >= 65 && uint8(char) <= 90) {
            return bytes1(uint8(char) + 32);
        } else {
            return char;
        }
    }

    function isSameString(
        string memory _a,
        string memory _b
    ) internal pure returns (bool) {
        return
            keccak256(abi.encodePacked(toLower(_a))) ==
            keccak256(abi.encodePacked(toLower(_b)));
    }
}
