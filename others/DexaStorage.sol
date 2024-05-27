// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import "./DexaBase.sol";
import "./DexaCreator.sol";
import "@bnb-chain/greenfield-contracts-sdk/BucketApp.sol";
import "@bnb-chain/greenfield-contracts-sdk/ObjectApp.sol";
import "@bnb-chain/greenfield-contracts-sdk/GroupApp.sol";

contract DexaStorage is Initializable, AccessControlUpgradeable, DexaBase {
    /**
     * @notice Error Codes
     * @notice 0 - 3 Defined in BaseApp.sol
     * @dev ERROR_INVALID_CALLER = "0"
     * @dev ERROR_INVALID_RESOURCE = "1"
     * @dev ERROR_INVALID_OPERATION = "2"
     * @dev ERROR_INSUFFICIENT_VALUE = "3"
     */

    /**
     * @notice Greenfield Contract Variables
     * @notice Docs https://github.com/bnb-chain/greenfield-contracts/tree/master/deployment
     * @notice Docs https://docs.bnbchain.org/greenfield-docs/docs/guide/core-concept/cross-chain/contract-list/
     */
    address public bucketToken;
    address public objectToken;
    address public groupToken;
    address public memberToken;

    /**
     * @notice DexaStorage Contract Variables
     */
    mapping(string => address) public creatorBucket;
    DexaCreator public dexaCreator;

    modifier onlyCreator() {
        bool isRole = dexaCreator.hasRole(CREATOR_ROLE, msg.sender);
        if (!isRole) {
            revert UnauthorisedAccess(
                ERROR_UNAUTHORISED_ACCESS,
                "You are not a creator"
            );
        }
        _;
    }

    /**
     * @notice Initialize function
     * @param _admin The address of the owner of this contract
     * @param _crossChain The address of the crossChain contract
     * @param _bucketHub The address of the bucketHub contract
     * @param _objectHub The address of the objectHub contract
     * @param _groupHub The address of the groupHub contract
     * @param _callbackGasLimit The gas limit for callback functions
     * @param _failureHandleStrategy The strategy for handling failures
     */
    function init_dexa_storage(
        address _dexaCreator,
        address _admin,
        address _crossChain,
        address _bucketHub,
        address _objectHub,
        address _groupHub,
        uint256 _callbackGasLimit,
        uint8 _failureHandleStrategy
    ) public initializer {
        __AccessControl_init();
        DexaBase.init_dexa_base(_admin);
        _grantRole(DEFAULT_ADMIN_ROLE, _admin);
        dexaCreator = DexaCreator(_dexaCreator);
        bucketToken = CmnStorage(_bucketHub).ERC721Token();
        objectToken = CmnStorage(_objectHub).ERC721Token();
        groupToken = CmnStorage(_groupHub).ERC721Token();
        memberToken = GroupStorage(_groupHub).ERC1155Token();
        __base_app_init_unchained(
            _crossChain,
            _callbackGasLimit,
            _failureHandleStrategy
        );
        __bucket_app_init_unchained(_bucketHub);
        __group_app_init_unchained(_groupHub);
        __object_app_init_unchained(_objectHub);
    }

    /**
     * @notice External Function called by Greenfield Contracts
     * @param status The status of the operation
     * @param resourceType The type of the resource
     * @param operationType The type of operation
     * @param resourceId The ID of the resource
     * @param callbackData Additional callback data
     */
    function greenfieldCall(
        uint32 status,
        uint8 resourceType,
        uint8 operationType,
        uint256 resourceId,
        bytes calldata callbackData
    ) external override(BucketApp, ObjectApp, GroupApp) {
        require(
            msg.sender == bucketHub ||
                msg.sender == objectHub ||
                msg.sender == groupHub,
            string.concat("Dexa: ", ERROR_INVALID_CALLER)
        );

        if (resourceType == RESOURCE_BUCKET) {
            _bucketGreenfieldCall(
                status,
                operationType,
                resourceId,
                callbackData
            );
        } else if (resourceType == RESOURCE_OBJECT) {
            _objectGreenfieldCall(
                status,
                operationType,
                resourceId,
                callbackData
            );
        } else if (resourceType == RESOURCE_GROUP) {
            _groupGreenfieldCall(
                status,
                operationType,
                resourceId,
                callbackData
            );
        } else {
            revert(string.concat("Dexa: ", ERROR_INVALID_RESOURCE));
        }
    }

    /**
     * @notice createBucket function for Dexa
     * @param _owner The name of the bucket
     * @param _name The name of the bucket
     * @param _visibility Buckets access type
     * @param _paymentAddress User payment address
     * @param _spAddress Storage provider address
     * @param _expireHeight The height at which the storage will expire
     * @param _globalVirtualGroupFamilyId The ID of the global virtual group family
     * @param _chargedReadQuota The quota for charged reads from the storage
     */
    function createBucket(
        string calldata _name,
        BucketStorage.BucketVisibilityType _visibility,
        address _paymentAddress,
        address _spAddress,
        uint64 _expireHeight,
        uint32 _globalVirtualGroupFamilyId,
        bytes memory _sig,
        uint64 _chargedReadQuota,
        address _owner
    ) external payable onlyCreator {
        require(
            bytes(_name).length > 0,
            string.concat("Dexa: ", ERROR_INVALID_STRING)
        );
        require(
            creatorBucket[_name] == address(0),
            string.concat("Dexa: ", ERROR_DUPLICATE_RESOURCE)
        );
        bytes memory _callbackData = bytes(_name);
        _createBucket(
            _owner,
            _name,
            _visibility,
            _paymentAddress,
            _spAddress,
            _expireHeight,
            _globalVirtualGroupFamilyId,
            _sig,
            _chargedReadQuota,
            _owner,
            failureHandleStrategy,
            _callbackData,
            callbackGasLimit
        );
        creatorBucket[_name] = msg.sender;
    }

    function findBucket(string memory key) public view returns (address) {
        return creatorBucket[key];
    }
}
