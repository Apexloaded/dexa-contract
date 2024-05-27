// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import "@bnb-chain/greenfield-contracts-sdk/BucketApp.sol";
import "@bnb-chain/greenfield-contracts-sdk/ObjectApp.sol";
import "@bnb-chain/greenfield-contracts-sdk/GroupApp.sol";
import "@bnb-chain/greenfield-contracts/contracts/interface/IERC721NonTransferable.sol";
// import "@bnb-chain/greenfield-contracts/contracts/interface/IERC1155NonTransferable.sol";
import "@openzeppelin/contracts-upgradeable/access/AccessControlUpgradeable.sol";
import "@openzeppelin/contracts-upgradeable/proxy/utils/Initializable.sol";
import "./DexaFeed.sol";

error UnauthorisedAccess(string code, string msg);
error NotFound(string code, string msg);
error ChargeFailed(uint256 amount, string msg);

struct Creator {
    string fullname;
    string username;
    address payable wallet;
    string profileURI;
    string bio;
    uint256 balance;
}

struct Post {
    uint256 id;
    address payable author;
    string content;
    uint256 price; // Optional price in wei
    address owner;
    uint256 timestamp;
    uint256 remintCount;
    address[] remintedBy;
}

struct Tips {
    uint256 postId;
    uint256 amount;
    address from;
    address to;
    string message;
    uint256 timestamp;
}

contract DexaGnf is AccessControlUpgradeable, BucketApp, ObjectApp, GroupApp {
    /**
     * @notice Dexa Contract Events
     */
    event NewCreator(address indexed creator, string fullname, string username);
    event Tipped(
        address indexed from,
        address indexed to,
        uint256 amount,
        uint256 indexed postId
    );
    event PostMinted(address indexed creator, uint256 indexed postId);
    event Reminted(
        address indexed minter,
        address indexed reminter,
        uint256 indexed postId
    );

    /**
     * @notice Roles Variable
     */
    bytes32 public constant CREATOR_ROLE = keccak256("CREATOR_ROLE");

    /**
     * @notice Error Codes
     * @notice 0 - 3 Defined in BaseApp.sol
     * @dev ERROR_INVALID_CALLER = "0"
     * @dev ERROR_INVALID_RESOURCE = "1"
     * @dev ERROR_INVALID_OPERATION = "2"
     * @dev ERROR_INSUFFICIENT_VALUE = "3"
     */
    string public constant ERROR_INVALID_STRING = "4";
    string public constant ERROR_DUPLICATE_RESOURCE = "5";
    string public constant ERROR_INVALID_PRICE = "6";
    string public constant ERROR_NOT_FOUND = "7";

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
     * @notice Dexa Contract Variables
     */
    uint256 public feeRate; // Dexa transaction fee
    uint256 public postCount; // Track number of posts on Dexa
    uint256 public tipsCount; // Track number of tips on Dexa
    address public owner;
    uint256 private constant MIN_POST_BAL = 1; // Min amount of post
    DexaFeed public dexaFeedToken; // DexaFeed Token;

    /**
     * @notice Dexa Mapping Variables
     */
    mapping(string => address) private creatorBucket;
    mapping(address => Creator) private _creators;
    mapping(uint256 => Post) private _posts;
    mapping(uint256 => Tips) private _tips;

    modifier postExists(uint256 postId) {
        bool isPost = _posts[postId].author != address(0);
        if (!isPost) {
            revert NotFound(ERROR_NOT_FOUND, "Post does not exist");
        }
        _;
    }

    modifier isPostOwner(uint256 postId) {
        if (_posts[postId].author == msg.sender) {
            revert UnauthorisedAccess(
                ERROR_INVALID_CALLER,
                "You own this post"
            );
        }
        _;
    }

    /**
     * @notice Initialize function
     * @param _admin The address of the administrator
     * @param _feeRate The fee rate for Dexa transactions
     * @param _crossChain The address of the crossChain contract
     * @param _bucketHub The address of the bucketHub contract
     * @param _objectHub The address of the objectHub contract
     * @param _groupHub The address of the groupHub contract
     * @param _callbackGasLimit The gas limit for callback functions
     * @param _failureHandleStrategy The strategy for handling failures
     */
    function initialize(
        address _admin,
        uint256 _feeRate,
        address _dexaFeed,
        address _crossChain,
        address _bucketHub,
        address _objectHub,
        address _groupHub,
        uint256 _callbackGasLimit,
        uint8 _failureHandleStrategy
    ) public initializer {
        __AccessControl_init();
        _grantRole(DEFAULT_ADMIN_ROLE, _admin);
        postCount = 0;
        tipsCount = 0;
        owner = _admin;
        feeRate = _feeRate;
        dexaFeedToken = DexaFeed(_dexaFeed);
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

    /*************************************************
     * @notice Creators functions
     *************************************************/

    /**
     * @notice Register a new creator
     * @param fullname The full name of the creator
     * @param username The username of the creator
     * @param dexaProfile The profile URI of the creator
     * @param bio The biography of the creator
     */
    function registerCreator(
        string memory fullname,
        string memory username,
        string memory dexaProfile,
        string memory bio
    ) public {
        require(
            _creators[msg.sender].wallet == address(0),
            string.concat("Dexa: ", ERROR_DUPLICATE_RESOURCE)
        );
        require(
            bytes(fullname).length > 0 &&
                bytes(username).length > 0 &&
                bytes(dexaProfile).length > 0 &&
                bytes(bio).length > 0,
            string.concat("Dexa: ", ERROR_INVALID_STRING)
        );
        _creators[msg.sender] = Creator(
            fullname,
            username,
            payable(msg.sender),
            dexaProfile,
            bio,
            0
        );
        emit NewCreator(msg.sender, fullname, username);
    }

    /**
     *
     * @param _name The name of the bucket
     * @param _visibility Buckets access type
     * @param _paymentAddress User payment address
     * @param _spAddress Storage provider address
     * @param _expireHeight The height at which the storage will expire
     * @param _globalVirtualGroupFamilyId The ID of the global virtual group family
     * @param _sig The signature for the storage creation
     * @param _chargedReadQuota The quota for charged reads from the storage
     */
    function createStorage(
        string calldata _name,
        BucketStorage.BucketVisibilityType _visibility,
        address _paymentAddress,
        address _spAddress,
        uint64 _expireHeight,
        uint32 _globalVirtualGroupFamilyId,
        bytes calldata _sig,
        uint64 _chargedReadQuota
    ) external onlyRole(CREATOR_ROLE) {
        require(
            bytes(_name).length > 0,
            string.concat("Dexa: ", ERROR_INVALID_STRING)
        );
        require(
            creatorBucket[_name] == address(0),
            string.concat("Dexa: ", ERROR_DUPLICATE_RESOURCE)
        );
        _createBucket(
            msg.sender,
            _name,
            _visibility,
            _paymentAddress,
            _spAddress,
            _expireHeight,
            _globalVirtualGroupFamilyId,
            _sig,
            _chargedReadQuota
        );
    }

    /**
     * @notice Returns a particular creator info
     * @param key This is creators address
     */
    function findCreator(address key) public view returns (Creator memory) {
        Creator memory creator = _creators[key];
        return creator;
    }

    /*************************************************
     * @notice Dexa Feeds Functions
     *************************************************/

    function mintPost(
        string memory content,
        uint256 price,
        string memory tokenURI
    ) public onlyRole(CREATOR_ROLE) {
        require(
            bytes(content).length > 0 && bytes(tokenURI).length > 0,
            string.concat("Dexa: ", ERROR_INVALID_STRING)
        );
        _posts[postCount] = Post({
            id: postCount,
            author: payable(msg.sender),
            content: content,
            price: price,
            owner: address(0),
            timestamp: block.timestamp,
            remintCount: 0,
            remintedBy: new address[](0)
        });

        bytes memory metaData = abi.encodePacked("Dexa", content);
        DexaFeed(dexaFeedToken).mint(
            msg.sender,
            postCount,
            10,
            metaData,
            tokenURI
        );
        emit PostMinted(msg.sender, postCount);
        postCount++;
    }

    function listAllPosts() public view returns (Post[] memory) {
        Post[] memory posts = new Post[](postCount);
        for (uint i = 1; i <= postCount; i++) {
            posts[i - 1] = _posts[i - 1];
        }
        return posts;
    }

    function postByCreator(
        address creator
    ) public view returns (Post[] memory) {
        uint256 creatorPostCount = 0;
        for (uint256 i = 0; i < postCount; i++) {
            if (_posts[i].author == creator) {
                creatorPostCount++;
            }
        }

        Post[] memory posts = new Post[](creatorPostCount);
        uint256 index = 0;

        for (uint256 i = 0; i < postCount; i++) {
            if (_posts[i].author == creator) {
                posts[index] = _posts[i];
                index++;
            }
        }

        return posts;
    }

    function getPost(uint256 postId) public view returns (Post memory) {
        Post memory post = _posts[postId];
        return post;
    }

    function tipPost(
        uint256 postId,
        string memory message
    ) public payable postExists(postId) isPostOwner(postId) {
        Post memory post = _posts[postId];
        Creator storage creator = _creators[post.author];
        creator.balance = creator.balance + msg.value;

        _tips[tipsCount] = Tips(
            post.id,
            msg.value,
            msg.sender,
            post.author,
            message,
            block.timestamp
        );

        emit Tipped(msg.sender, post.author, msg.value, postId);
    }

    function remintPost(
        uint256 postId
    ) public payable postExists(postId) isPostOwner(postId) {
        Post memory post = _posts[postId];

        require(msg.value >= post.price, "Remint amount too low");

        uint256 mintersBal = DexaFeed(dexaFeedToken).balance(
            msg.sender,
            postId
        );
        uint256 authorsBal = DexaFeed(dexaFeedToken).balance(
            post.author,
            postId
        );
        require(mintersBal == 0, "Already reminted");
        require(authorsBal > MIN_POST_BAL, "Minimum re-mint balance reached");

        uint256 remintCharge = chargefee(msg.value);
        uint256 creatorBal = msg.value - remintCharge;

        Creator storage creator = _creators[post.author];
        creator.balance = creatorBal;

        DexaFeed(dexaFeedToken).transfer(
            post.author,
            msg.sender,
            postId,
            MIN_POST_BAL
        );

        _posts[postId].remintedBy.push(msg.sender);
        _posts[postId].remintCount++;

        emit Reminted(post.author, msg.sender, postId);
    }

    /*************************************************
     * @notice Internal Functions
     *************************************************/
    function chargefee(uint256 _amount) private returns (uint256) {
        uint256 mintCharge = (_amount * feeRate) / 1000;
        uint256 charge = _amount - mintCharge;
        (bool success, ) = address(owner).call{value: charge}("");
        if (!success) {
            revert ChargeFailed(_amount, "Charge failed");
        }
        return charge;
    }
}
