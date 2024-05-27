// SPDX-License-Identifier: MIT
pragma solidity ^0.8.9;

import "@openzeppelin/contracts-upgradeable/proxy/utils/Initializable.sol";
import "@openzeppelin/contracts-upgradeable/token/ERC1155/ERC1155Upgradeable.sol";
import "@openzeppelin/contracts-upgradeable/access/OwnableUpgradeable.sol";
import "@openzeppelin/contracts-upgradeable/token/ERC1155/extensions/ERC1155PausableUpgradeable.sol";
import "@openzeppelin/contracts-upgradeable/token/ERC1155/extensions/ERC1155SupplyUpgradeable.sol";
import "@openzeppelin/contracts/utils/Base64.sol";
import "@openzeppelin/contracts/utils/Strings.sol";

error NotAdmin(string msg);
error ChargeFailed(uint256 amount, string msg);
error NotCreator(string msg, address creator);
error PostOwner(string msg, address owner);
error ContractPaused(string msg);
error InvalidString(string msg);
error PostExist(string msg);

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

contract Dexa is
    Initializable,
    ERC1155Upgradeable,
    OwnableUpgradeable,
    ERC1155PausableUpgradeable,
    ERC1155SupplyUpgradeable
{
    event NewCreator(address indexed creator, string fullname, string username);
    event Tipped(
        address indexed from,
        address indexed to,
        uint256 amount,
        uint256 indexed postId
    );
    event Reminted(
        address indexed minter,
        address indexed reminter,
        uint256 indexed postId
    );

    uint256 private constant MAX_MINT = 10;
    uint256 private constant MIN_POST_BAL = 1;

    address private _admin;
    uint256 private _postIds;
    uint256 private _tipsIds;
    uint256 private _mintPercentage;
    mapping(address => Creator) private _creators;
    mapping(uint256 => Post) private _posts;
    mapping(uint256 => Tips) private _tips;

    /**
     * -----------------------Modifiers---------------------------
     * -----------------------------------------------------------
     */

    modifier isCreator() {
        if (_creators[msg.sender].wallet == address(0)) {
            revert NotCreator("Unauthorised access", msg.sender);
        }
        _;
    }

    modifier isAdmin() {
        if (msg.sender != _admin) {
            revert NotAdmin("Unauthorised access");
        }
        _;
    }

    modifier isContractLocked() {
        if (paused()) {
            revert ContractPaused("Contract is lock");
        }
        _;
    }

    modifier isEmpty(string memory s, string memory error) {
        if (bytes(s).length == 0) {
            revert InvalidString(error);
        }
        _;
    }

    modifier postExists(uint256 postId) {
        bool isPost = _posts[postId].author != address(0);
        if (!isPost) {
            revert PostExist("Post does not exist");
        }
        _;
    }

    modifier postOwner(uint256 postId) {
        if (_posts[postId].author == msg.sender) {
            revert PostOwner("You own this post", msg.sender);
        }
        _;
    }

    /**
     * -----------------------Initializer---------------------------
     * -------------------------------------------------------------
     */

    function initialize(
        address _dexa,
        uint256 mintPerctage
    ) public initializer {
        _admin = _dexa;
        __ERC1155_init("");
        __Ownable_init(_dexa);
        __ERC1155Pausable_init();
        __ERC1155Supply_init();
        _postIds = 0;
        _tipsIds = 0;
        _mintPercentage = mintPerctage;
    }

    /**
     * -----------------------Instance Functions---------------------------
     * --------------------------------------------------------------------
     */
    function creatorInstance(
        address key
    ) private view returns (Creator memory) {
        return _creators[key];
    }

    function postInstance(uint256 postId) private view returns (Post memory) {
        return _posts[postId];
    }

    /**
     * -----------------------Creators Functions---------------------------
     * --------------------------------------------------------------------
     */
    function registerCreator(
        string memory fullname,
        string memory username,
        string memory profileURI,
        string memory bio
    )
        public
        isContractLocked
        isEmpty(fullname, "Invalid name entered")
        isEmpty(username, "Invalid username")
        isEmpty(profileURI, "invalid profile URI")
        isEmpty(bio, "Invalid user biography")
    {
        Creator storage _creator = _creators[msg.sender];
        _creator.fullname = fullname;
        _creator.username = username;
        _creator.wallet = payable(msg.sender);
        _creator.profileURI = profileURI;
        _creator.bio = bio;
        emit NewCreator(msg.sender, fullname, username);
    }

    function getCreator(address key) public view returns (Creator memory) {
        Creator memory creator = creatorInstance(key);
        return creator;
    }

    /**
     * -----------------------Posts Functions---------------------------
     * -----------------------------------------------------------------
     */
    function mintPost(
        string memory content,
        uint256 price,
        string memory tokenURI
    ) public isCreator isContractLocked {
        Post storage post = _posts[_postIds];
        post.id = _postIds;
        post.author = payable(msg.sender);
        post.content = content;
        post.price = price;
        post.owner = address(0);
        post.timestamp = block.timestamp;

        bytes memory metaData = abi.encodePacked("CL-", content);
        mint(msg.sender, _postIds, MAX_MINT, metaData);
        _setURI(tokenURI);
        _postIds++;
    }

    function listAllPosts() public view returns (Post[] memory) {
        Post[] memory posts = new Post[](_postIds);
        for (uint i = 1; i <= _postIds; i++) {
            posts[i - 1] = postInstance(i - 1);
        }
        return posts;
    }

    function postByCreator(
        address creator
    ) public view returns (Post[] memory) {
        uint256 creatorPostCount = 0;
        for (uint256 i = 0; i < _postIds; i++) {
            if (_posts[i].author == creator) {
                creatorPostCount++;
            }
        }

        Post[] memory posts = new Post[](creatorPostCount);
        uint256 index = 0;

        for (uint256 i = 0; i < _postIds; i++) {
            if (_posts[i].author == creator) {
                posts[index] = _posts[i];
                index++;
            }
        }

        return posts;
    }

    function getPost(uint256 postId) public view returns (Post memory) {
        Post memory post = postInstance(postId);
        return post;
    }

    function tipPost(
        uint256 postId,
        string memory message
    ) public payable postExists(postId) postOwner(postId) {
        Post memory post = postInstance(postId);

        Creator storage creator = _creators[post.author];
        creator.balance = creator.balance + msg.value;

        Tips storage tips = _tips[_tipsIds];
        tips.postId = post.id;
        tips.amount = msg.value;
        tips.from = msg.sender;
        tips.message = message;
        tips.to = post.author;
        tips.timestamp = block.timestamp;

        emit Tipped(msg.sender, post.author, msg.value, postId);
    }

    function remintPost(
        uint256 postId
    ) public payable postExists(postId) postOwner(postId) {
        Post memory post = postInstance(postId);

        require(msg.value >= post.price, "Remint amount too low");

        uint256 mintersBal = balanceOf(msg.sender, postId);
        uint256 authorsBal = balanceOf(post.author, postId);
        require(mintersBal == 0, "Already reminted");
        require(authorsBal > MIN_POST_BAL, "Minimum re-mint balance reached");

        uint256 remintCharge = chargeRemintPerc(msg.value);
        uint256 creatorBal = msg.value - remintCharge;

        Creator storage creator = _creators[post.author];
        creator.balance = creatorBal;

        _safeTransferFrom(post.author, msg.sender, postId, MIN_POST_BAL, "");

        _posts[postId].remintedBy.push(msg.sender);
        _posts[postId].remintCount++;

        emit Reminted(post.author, msg.sender, postId);
    }

    /**
     * -----------------------Admin Functions---------------------------
     * -----------------------------------------------------------------
     */

    function updateAdmin(address owner) public isAdmin {
        _admin = payable(owner);
    }

    function pause() public onlyOwner {
        _pause();
    }

    function unpause() public onlyOwner {
        _unpause();
    }

    function setReMintPercent(uint256 percentage) external onlyOwner {
        // Ensure the service charge is within reasonable bounds
        require(percentage <= 1000, "Percentage exceeds 100%");
        _mintPercentage = percentage;
    }

    function chargeRemintPerc(uint256 _amount) private returns (uint256) {
        uint256 mintCharge = (_amount * _mintPercentage) / 1000;
        uint256 charge = _amount - mintCharge;
        (bool success, ) = address(_admin).call{value: charge}("");
        if (!success) {
            revert ChargeFailed(_amount, "Charge failed");
        }
        return charge;
    }

    function mint(
        address account,
        uint256 id,
        uint256 amount,
        bytes memory data
    ) private isCreator {
        _mint(account, id, amount, data);
    }

    /**
     * -----------------------Internal Functions---------------------------
     * --------------------------------------------------------------------
     */
    // function generateURI(
    //     uint256 postId,
    //     string memory description,
    //     string memory ipfsHash,
    //     string memory dexaURI
    // ) internal view returns (string memory) {
    //     Post memory post = postInstance(postId);
    //     Creator memory creator = creatorInstance(post.author);
    //     string memory uri = Base64.encode(
    //         bytes(
    //             string(
    //                 abi.encodePacked(
    //                     '{',
    //                         '"name": "Dexa #', Strings.toString(postId), '",',
    //                         '"description": "', description, '",',
    //                         '"image": "', ipfsHash, '",',
    //                         '"external_url": "', dexaURI, '",',
    //                         '"background_color": "ffffff",',
    //                         '"attributes": [', 
    //                             '{',
    //                                 '"trait_type": "Creator Name",',
    //                                 '"value": "', creator.fullname, '"',
    //                             '}',
    //                         ']', 
    //                     '{'
    //                 )
    //             )
    //         )
    //     );

    //     return string(abi.encodePacked("data:application/json;base64,", uri));
    // }

    function _update(
        address from,
        address to,
        uint256[] memory ids,
        uint256[] memory values
    )
        internal
        override(
            ERC1155Upgradeable,
            ERC1155PausableUpgradeable,
            ERC1155SupplyUpgradeable
        )
    {
        super._update(from, to, ids, values);
    }
}
