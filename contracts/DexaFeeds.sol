// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

import "./DexaBase.sol";
import "./DexaCreator.sol";
import "./FeedsToken.sol";
import "@openzeppelin/contracts-upgradeable/token/ERC20/ERC20Upgradeable.sol";
import "@openzeppelin/contracts/utils/Strings.sol";

struct Media {
    string url;
    string mimetype;
}

struct PostCreator {
    string name;
    string username;
    string pfp;
}

struct Post {
    string id;
    address payable author;
    string content;
    uint256 remintPrice; // Optional price in wei
    uint256 remintCount;
    address[] remintedBy;
    address remintToken;
    uint256 tipCount;
    Media[] media;
    string metadataURI;
    uint256 tokenId;
    uint256 createdAt;
    PostCreator creator;
    bool isReminted;
    uint256 remintedPost;
    address[] likedBy;
    uint256 parentId;
    uint256 commentCount;
    bool isMintable; // This is supposed to be isComment, so it's used for comment
}

struct Tips {
    uint256 postId;
    uint256 tipSent;
    uint256 tipReceived;
    address from;
    address to;
    string message;
    uint256 timestamp;
    address tokenAddress;
}

contract DexaFeeds is DexaBase {
    /**
     * @notice DexaFeed Contract Events
     */
    event Tipped(
        address indexed from,
        address indexed to,
        uint256 amount,
        uint256 indexed postId,
        string offChainId,
        string message,
        address tippedToken,
        uint256 tipId
    );
    event PostMinted(
        address indexed creator,
        uint256 indexed postId,
        string gnfdId,
        address remintToken,
        uint256 remintPrice
    );

    /**
     * @notice DexaFeed Contract Variables
     */
    uint256 public postCount; // Track number of posts on DexaFeed
    uint256 public tipsCount; // Track number of tips on DexaFeed
    uint256 private constant MIN_POST_BAL = 1; // Min amount of post
    DexaCreator public dexaCreator;
    FeedsToken public feedsToken;
    address private dexaCreatorAddr;

    /**
     * @notice DexaFeed Mapping Variables
     */
    mapping(uint256 => Post) private _posts;
    mapping(uint256 => Tips) private _tips;
    mapping(string => uint256) public gnfdId; // Greenfield Id
    mapping(address => mapping(address => Tips[])) private _creatorTips; // Mapping to store tips received by a creator for each token type
    mapping(uint256 => Media[]) public postMedia;
    mapping(uint256 => mapping(address => bool)) private _hasReminted; // New mapping to track remints
    mapping(uint256 => mapping(address => bool)) private _hasLiked; // New mapping to track remints
    mapping(uint256 => uint256[]) private _postComments; // Mapping to track comments for each post

    modifier postExists(uint256 postId) {
        require(
            _posts[postId].author != address(0),
            string.concat("Dexa: ", ERROR_NOT_FOUND)
        );
        _;
    }

    modifier isPostOwner(uint256 postId) {
        if (_posts[postId].author == msg.sender) {
            revert(string.concat("Dexa: ", ERROR_UNAUTHORISED_ACCESS));
        }
        _;
    }

    modifier isCreator() {
        require(
            dexaCreator.hasRole(CREATOR_ROLE, msg.sender),
            string.concat("Dexa: ", ERROR_UNAUTHORISED_ACCESS)
        );
        _;
    }

    /**
     * @notice Initialize DexaFeed Token
     */
    function init_dexa_feed(
        address payable _dexaCreator,
        address _admin,
        address _feedsTokenAddr
    ) public initializer {
        __AccessControl_init();
        dexaCreatorAddr = _dexaCreator;
        dexaCreator = DexaCreator(_dexaCreator);
        feedsToken = FeedsToken(_feedsTokenAddr);
        DexaBase.init_dexa_base(_admin);
    }

    function init_roles(
        address _dexaCreator
    ) external onlyRole(DEFAULT_ADMIN_ROLE) {
        _grantRole(DEXA_CREATOR_ROLE, _dexaCreator);
        _grantRole(DEXA_FEEDS_ROLE, address(this));
    }

    /*************************************************
     * @notice Dexa Feeds Functions
     *************************************************/

    function mintPost(
        string memory tokenId,
        string memory content,
        uint256 price,
        address tokenAddress,
        string memory metadataURI,
        Media[] memory media
    ) public isCreator {
        require(
            bytes(content).length > 0,
            string.concat("Dexa: ", ERROR_INVALID_STRING)
        );
        require(
            gnfdId[tokenId] == 0,
            string.concat("Dexa: ", ERROR_DUPLICATE_RESOURCE)
        );

        Post storage post = _posts[postCount];
        post.id = tokenId;
        post.author = payable(msg.sender);
        post.content = content;
        post.remintPrice = price;
        post.metadataURI = string.concat(
            metadataURI,
            "/",
            Strings.toString(postCount),
            ".json"
        );
        post.createdAt = block.timestamp;
        post.remintToken = tokenAddress;
        post.tokenId = postCount;

        Media[] storage _postMedia = postMedia[postCount];
        for (uint256 i; i < media.length; i++) {
            _postMedia.push(media[i]);
            _posts[postCount].media.push(media[i]);
        }

        feedsToken.mint(msg.sender, postCount, 10, "");
        gnfdId[tokenId] = postCount;
        emit PostMinted(msg.sender, postCount, tokenId, tokenAddress, price);
        postCount++;
    }

    function listOnlyMainPosts() public view returns (Post[] memory) {
        uint256 _postCount = 0;
        for (uint256 i = 0; i < postCount; i++) {
            if (!_posts[i].isMintable) {
                // Using isMintable in place of comment
                _postCount++;
            }
        }

        Post[] memory posts = new Post[](_postCount);
        uint256 index = 0;
        for (uint256 i; i < postCount; i++) {
            if (!_posts[i].isMintable) {
                // Using isMintable in place of comment
                posts[index] = postBygnfdId(_posts[i].id);
                index++;
            }
        }
        return posts;
    }

    function listAllPosts() public view returns (Post[] memory) {
        Post[] memory posts = new Post[](postCount);
        for (uint256 i; i < postCount; i++) {
            posts[i] = postBygnfdId(_posts[i].id);
        }
        return posts;
    }

    function postByCreator(
        string memory username
    ) public view returns (Post[] memory) {
        address creator = dexaCreator.findCreatorByUsername(username).wallet;
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
                posts[index] = getPost(i);
                index++;
            }
        }

        return posts;
    }

    function postBygnfdId(string memory id) public view returns (Post memory) {
        uint256 tokenId = gnfdId[id];
        return generatePost(tokenId);
    }

    function getPost(uint256 postId) public view returns (Post memory) {
        return generatePost(postId);
    }

    function generatePost(uint256 postId) private view returns (Post memory) {
        Creator memory creator = dexaCreator.findCreator(_posts[postId].author);
        return
            Post(
                _posts[postId].id,
                _posts[postId].author,
                _posts[postId].content,
                _posts[postId].remintPrice,
                _posts[postId].remintCount,
                _posts[postId].remintedBy,
                _posts[postId].remintToken,
                _posts[postId].tipCount,
                _posts[postId].media,
                _posts[postId].metadataURI,
                postId,
                _posts[postId].createdAt,
                PostCreator(creator.name, creator.username, creator.pfp),
                _posts[postId].isReminted,
                _posts[postId].remintedPost,
                _posts[postId].likedBy,
                _posts[postId].parentId,
                _postComments[postId].length,
                _posts[postId].isMintable
            );
    }

    /**
     * @dev send msg.value with address(0) as tokenAddress for native token
     * and tipAmount with other allowed tokenAddress to send other token
     * @param postId onchain minted token ID
     * @param message optional message for the user
     * @param tokenAddress the token address you are tipping from
     * @param tipAmount the amount to be tipped
     */
    function tipPost(
        uint256 postId,
        string memory message,
        address tokenAddress,
        uint256 tipAmount
    ) public payable isPostOwner(postId) onlyAllowedToken(tokenAddress) {
        require(
            _posts[postId].author != address(0),
            string.concat("Dexa: ", ERROR_NOT_FOUND)
        );
        uint256 amount;
        if (tokenAddress == address(0)) {
            amount = msg.value;
            dexaCreator.acceptPayment{value: msg.value}();
        } else {
            amount = tipAmount;
        }

        require(amount > 0, string.concat("Dexa: ", ERROR_INVALID_PRICE));

        if (tokenAddress != address(0)) {
            ERC20Upgradeable token = ERC20Upgradeable(tokenAddress);
            require(
                token.balanceOf(msg.sender) >= amount,
                string.concat("Dexa: ", ERROR_INVALID_PRICE)
            );
            require(
                token.transferFrom(msg.sender, dexaCreatorAddr, amount),
                string.concat("Dexa: ", ERROR_PROCESS_FAILED)
            );
        }

        Post memory post = _posts[postId];
        uint256 fee = chargefee(amount);
        uint256 creatorBal = amount - fee;
        dexaCreator.creditBalance(post.author, tokenAddress, creatorBal);
        dexaCreator.createTransaction(
            TransactionType.Tip,
            msg.sender,
            post.author,
            amount,
            fee
        );
        Tips memory tip = Tips(
            postId,
            amount,
            creatorBal,
            msg.sender,
            post.author,
            message,
            block.timestamp,
            tokenAddress
        );
        _tips[tipsCount] = tip;
        _posts[postId].tipCount++;
        _creatorTips[post.author][tokenAddress].push(tip);
        emit Tipped(
            msg.sender,
            post.author,
            amount,
            postId,
            post.id,
            message,
            tokenAddress,
            tipsCount
        );
        tipsCount++;
    }

    function remintPost(
        uint256 postId,
        address tokenAddress,
        string memory content,
        string memory newPostId
    ) public payable isPostOwner(postId) {
        Post memory post = _posts[postId];
        uint256 mintersBal = feedsToken.balanceOf(msg.sender, postId);
        uint256 authorsBal = feedsToken.balanceOf(post.author, postId);
        require(
            mintersBal == 0 &&
                gnfdId[newPostId] == 0 &&
                !_hasReminted[postId][msg.sender],
            string.concat("Dexa: ", ERROR_DUPLICATE_RESOURCE)
        );
        require(
            authorsBal > MIN_POST_BAL,
            string.concat("Dexa: ", ERROR_PROCESS_FAILED)
        );

        if (tokenAddress == address(0)) {
            require(
                msg.value >= post.remintPrice,
                string.concat("Dexa: ", ERROR_INVALID_PRICE)
            );
            dexaCreator.acceptPayment{value: msg.value}();
        } else {
            ERC20Upgradeable token = ERC20Upgradeable(tokenAddress);
            require(
                token.balanceOf(msg.sender) >= post.remintPrice,
                string.concat("Dexa: ", ERROR_INVALID_PRICE)
            );
            require(
                token.transferFrom(
                    msg.sender,
                    dexaCreatorAddr,
                    post.remintPrice
                ),
                string.concat("Dexa: ", ERROR_PROCESS_FAILED)
            );
        }

        uint256 fee = chargefee(post.remintPrice);
        uint256 creatorBal = post.remintPrice - fee;
        dexaCreator.creditBalance(post.author, tokenAddress, creatorBal);
        dexaCreator.createTransaction(
            TransactionType.Remint,
            msg.sender,
            post.author,
            post.remintPrice,
            fee
        );

        _posts[postId].remintedBy.push(msg.sender);
        _posts[postId].remintCount++;
        _hasReminted[postId][msg.sender] = true;

        Post storage newPost = _posts[postCount];
        newPost.id = newPostId;
        newPost.author = payable(msg.sender);
        newPost.content = content;
        newPost.createdAt = block.timestamp;
        newPost.tokenId = postCount;
        newPost.isReminted = true;
        newPost.remintedPost = postId;

        feedsToken.transfer(post.author, msg.sender, postId, MIN_POST_BAL, "");

        gnfdId[newPostId] = postCount;
        postCount++;
    }

    function commentOnPost(
        uint256 postId,
        string calldata commentId,
        string calldata content
    ) external postExists(postId) isCreator {
        require(
            bytes(content).length > 0,
            string.concat("Dexa: ", ERROR_INVALID_STRING)
        );

        Post storage newPost = _posts[postCount];
        newPost.id = commentId;
        newPost.author = payable(msg.sender);
        newPost.content = content;
        newPost.createdAt = block.timestamp;
        newPost.tokenId = postCount;
        newPost.parentId = postId; // Set the parentId to the post being commented on
        newPost.isMintable = true; // This is supposed to be isComment

        _postComments[postId].push(postCount); // Add the comment to the parent post's comments list

        gnfdId[newPost.id] = postCount;
        postCount++;
    }

    function getComments(
        uint256 postId
    ) external view postExists(postId) returns (Post[] memory) {
        uint256[] storage commentIds = _postComments[postId];
        Post[] memory comments = new Post[](commentIds.length);
        for (uint256 i = 0; i < commentIds.length; i++) {
            comments[i] = generatePost(commentIds[i]);
        }
        return comments;
    }

    function likePost(uint256 postId) public postExists(postId) {
        if (!_hasLiked[postId][msg.sender]) {
            _posts[postId].likedBy.push(msg.sender);
            _hasLiked[postId][msg.sender] = false;
        } else {
            _removeLike(postId, msg.sender);
            _hasLiked[postId][msg.sender] = false;
        }
    }

    function _removeLike(uint256 postId, address liker) internal {
        uint256 length = _posts[postId].likedBy.length;
        for (uint256 i = 0; i < length; i++) {
            if (_posts[postId].likedBy[i] == liker) {
                _posts[postId].likedBy[i] = _posts[postId].likedBy[length - 1];
                _posts[postId].likedBy.pop();
                break;
            }
        }
    }

    function getCreatorTipsByToken(
        address creator,
        address tokenAddress
    ) public view returns (Tips[] memory) {
        Tips[] memory tips = _creatorTips[creator][tokenAddress];
        return tips;
    }

    function getAllCreatorTips(
        address creator
    ) public view returns (Tips[] memory) {
        uint256 creatorTipCount;
        for (uint256 i; i < tipsCount; i++) {
            if (_tips[i].to == creator) {
                creatorTipCount++;
            }
        }

        Tips[] memory tips = new Tips[](creatorTipCount);
        uint256 index;

        for (uint256 i; i < tipsCount; i++) {
            if (_tips[i].to == creator) {
                tips[index] = _tips[i];
                index++;
            }
        }

        return tips;
    }
}
