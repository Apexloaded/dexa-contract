// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

import "./DexaBase.sol";
import "./DexaCreator.sol";
import "./DexaFeeds.sol";

struct Request {
    address sender;
    uint256 createdAt;
}

struct Friend {
    address id;
    string name;
    string username;
    string pfp;
}

struct Chat {
    address sender;
    string message;
    Media[] media;
    uint256 createdAt;
}

struct UserChats {
    address sender;
    Chat[] chats;
    Friend profile;
}

contract DexaMessenger is DexaBase {
    event ChatSent(
        bytes32 indexed chatCode,
        address indexed _from,
        address indexed _to
    );

    DexaCreator public dexaCreator;
    address private dexaCreatorAddr;

    mapping(bytes32 => Chat[]) private chats;
    mapping(address => Request[]) private _connectionReq;
    mapping(address => mapping(address => bool)) private isAccepted;
    mapping(address => mapping(address => bool)) private isRequestSent;

    modifier isFriend(address from, address to) {
        require(
            isAccepted[to][from],
            string.concat("Dexa: ", ERROR_UNAUTHORISED_ACCESS)
        );
        _;
    }

    modifier isCreator(address user) {
        require(
            dexaCreator.hasRole(CREATOR_ROLE, user),
            string.concat("Dexa: ", ERROR_UNAUTHORISED_ACCESS)
        );
        _;
    }

    /**
     * @notice Initialize DexaFeed Token
     */
    function init_dexa_messenger(
        address payable _dexaCreator,
        address _admin
    ) public initializer {
        __AccessControl_init();
        dexaCreatorAddr = _dexaCreator;
        dexaCreator = DexaCreator(_dexaCreator);
        DexaBase.init_dexa_base(_admin);
    }

    function init_roles(
        address _dexaCreator
    ) external onlyRole(DEFAULT_ADMIN_ROLE) {
        _grantRole(DEXA_CREATOR_ROLE, _dexaCreator);
        _grantRole(DEXA_MESSENGER_ROLE, address(this));
    }

    function sendConnectRequest(
        address to
    ) public isCreator(msg.sender) isCreator(to) {
        require(
            !isRequestSent[to][msg.sender] &&
                !isAccepted[to][msg.sender] &&
                to != msg.sender,
            string.concat("Dexa: ", ERROR_DUPLICATE_RESOURCE)
        );
        isRequestSent[to][msg.sender] = true;
        isAccepted[msg.sender][to] = true;
        _connectionReq[to].push(Request(msg.sender, block.timestamp));
        dexaCreator.addFriend(msg.sender, to);
    }

    function acceptConnectRequest(
        address from,
        uint256 index
    ) public isCreator(msg.sender) isCreator(from) {
        require(
            index < _connectionReq[msg.sender].length,
            string.concat("Dexa: ", ERROR_PROCESS_FAILED)
        );
        require(
            isRequestSent[msg.sender][from],
            string.concat("Dexa: ", ERROR_NOT_FOUND)
        );
        require(
            !isAccepted[msg.sender][from],
            string.concat("Dexa: ", ERROR_DUPLICATE_RESOURCE)
        );
        dexaCreator.addFriend(msg.sender, from);
        isAccepted[msg.sender][from] = true;
        _connectionReq[msg.sender][index] = _connectionReq[msg.sender][
            _connectionReq[msg.sender].length - 1
        ];
        _connectionReq[msg.sender].pop();
    }

    function removeOne(uint256 index) public {
        _connectionReq[msg.sender][index] = _connectionReq[msg.sender][
            _connectionReq[msg.sender].length - 1
        ];
        _connectionReq[msg.sender].pop();
    }

    function getConnectRequests()
        public
        view
        isCreator(msg.sender)
        returns (Request[] memory)
    {
        return _connectionReq[msg.sender];
    }

    function getFriendsList()
        external
        view
        isCreator(msg.sender)
        returns (Friend[] memory)
    {
        Creator memory creator = dexaCreator.findCreator(msg.sender);
        Friend[] memory friendList = new Friend[](creator.friends.length);
        for (uint256 i; i < creator.friends.length; i++) {
            Creator memory friend = dexaCreator.findCreator(creator.friends[i]);
            friendList[i] = Friend(
                friend.wallet,
                friend.name,
                friend.username,
                friend.pfp
            );
        }
        return friendList;
    }

    function checkFriendStatus(
        string calldata username
    ) public view returns (bool, bool) {
        Creator memory user = dexaCreator.findCreatorByUsername(username);
        return (
            isRequestSent[user.wallet][msg.sender],
            isAccepted[user.wallet][msg.sender]
        );
    }

    function _getChatCode(
        address from,
        address to
    ) internal pure returns (bytes32) {
        if (from < to) {
            return keccak256(abi.encodePacked(from, to));
        } else return keccak256(abi.encodePacked(to, from));
    }

    function sendMessage(
        address to,
        string calldata _msg,
        Media[] calldata _media
    ) external isFriend(msg.sender, to) isCreator(msg.sender) isCreator(to) {
        bytes32 chatCode = _getChatCode(msg.sender, to);
        chats[chatCode].push();
        Chat storage newChat = chats[chatCode][chats[chatCode].length - 1];
        newChat.sender = msg.sender;
        newChat.createdAt = block.timestamp;
        newChat.message = _msg;

        for (uint256 i = 0; i < _media.length; i++) {
            newChat.media.push(
                Media({url: _media[i].url, mimetype: _media[i].mimetype})
            );
        }
        emit ChatSent(chatCode, msg.sender, to);
    }

    function readChat(
        address from
    ) external view isCreator(msg.sender) returns (Chat[] memory) {
        bytes32 chatCode = _getChatCode(msg.sender, from);
        return chats[chatCode];
    }

    function getAllChats()
        external
        view
        isCreator(msg.sender)
        returns (UserChats[] memory)
    {
        Creator memory creator = dexaCreator.findCreator(msg.sender);
        uint256 validChatCount;

        for (uint256 i; i < creator.friends.length; i++) {
            bytes32 chatCode = _getChatCode(msg.sender, creator.friends[i]);
            if (chats[chatCode].length > 0) {
                validChatCount++;
            }
        }

        UserChats[] memory userChatsList = new UserChats[](validChatCount);
        uint256 currentIndex;

        for (uint256 i; i < creator.friends.length; i++) {
            bytes32 chatCode = _getChatCode(msg.sender, creator.friends[i]);
            Creator memory friend = dexaCreator.findCreator(creator.friends[i]);
            if (chats[chatCode].length > 0) {
                userChatsList[currentIndex].sender = creator.friends[i];
                userChatsList[currentIndex].chats = chats[chatCode];
                userChatsList[currentIndex].profile = Friend(
                    friend.wallet,
                    friend.name,
                    friend.username,
                    friend.pfp
                );
                currentIndex++;
            }
        }

        return userChatsList;
    }
}
