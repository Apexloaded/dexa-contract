// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

import "./DexaBase.sol";
import "@openzeppelin/contracts-upgradeable/access/AccessControlUpgradeable.sol";
import "@openzeppelin/contracts-upgradeable/proxy/utils/Initializable.sol";
import "@openzeppelin/contracts-upgradeable/token/ERC20/ERC20Upgradeable.sol";

struct TokenBalance {
    address tokenAddress;
    uint256 balance;
}

struct TokenData {
    address[] addresses; // Array to store token addresses
    mapping(address => bool) exists; // Mapping to check if token address exists
    mapping(address => uint256) balances; // Mapping of token address to balance
}

struct Creator {
    string name;
    string username;
    address payable wallet;
    string pfp;
    string banner;
    string bio;
    string website;
    string dexaURI;
    uint256 createdAt;
    uint256 updatedAt;
    address[] friends;
}

contract DexaCreator is DexaBase {
    /**
     * @notice DexaCreator Contract Events
     */
    event NewCreator(
        address indexed creator,
        string displayName,
        string username
    );
    event TokenAddressAdded(
        address indexed userAddress,
        address indexed tokenAddress
    );
    event BalanceCredited(address indexed userAddress, uint256 amount);
    event BalanceDebited(address indexed userAddress, uint256 amount);
    event Transferred(address indexed from, address indexed to, uint256 amount);

    /**
     * @notice DexaCreator Contract Variables
     */
    uint256 public creatorCount; // Track number of creator on Dexa
    uint256 public transactionCount;

    /**
     * @notice Dexa Mapping Variables
     */
    mapping(address => Creator) private _creators;
    mapping(uint256 => Transaction) private _transactions;
    mapping(string => address) private _usernames;
    mapping(address => TokenData) private _tokenData;
    address[] private _creatorAddresses;

    /*****************************************************
     * @notice Initialize function
     *****************************************************/

    /**
     *
     * @param _admin Initialize dexa creator app
     */
    function init_dexa_creator(address _admin) public initializer {
        __AccessControl_init();
        DexaBase.init_dexa_base(_admin);
    }

    function init_roles(
        address _dexaFeed,
        address _dexaMessenger
    ) external onlyRole(DEFAULT_ADMIN_ROLE) {
        _grantRole(DEXA_FEEDS_ROLE, _dexaFeed);
        _grantRole(DEXA_MESSENGER_ROLE, _dexaMessenger);
        _grantRole(DEXA_CREATOR_ROLE, address(this));
    }

    /**
     * @notice Register a new creator
     * @param displayName The full name of the creator
     * @param username The username of the creator
     * @param dexaProfile The profile URI of the creator
     */
    function registerCreator(
        string memory displayName,
        string memory username,
        string memory dexaProfile
    ) public {
        string memory name = toLower(username);
        require(
            _creators[msg.sender].wallet == address(0),
            string.concat("Dexa: ", ERROR_DUPLICATE_RESOURCE)
        );
        require(
            _usernames[name] == address(0),
            string.concat("Dexa: ", ERROR_DUPLICATE_RESOURCE)
        );
        require(
            bytes(displayName).length > 0 &&
                bytes(username).length > 0 &&
                bytes(dexaProfile).length > 0,
            string.concat("Dexa: ", ERROR_INVALID_STRING)
        );

        Creator storage newCreator = _creators[msg.sender];
        newCreator.name = displayName;
        newCreator.username = name;
        newCreator.wallet = payable(msg.sender);
        newCreator.dexaURI = dexaProfile;
        newCreator.createdAt = block.timestamp;
        _usernames[name] = msg.sender;

        _creatorAddresses.push(msg.sender);
        _grantRole(CREATOR_ROLE, msg.sender);
        emit NewCreator(msg.sender, displayName, username);
    }

    function editProfile(
        string memory name,
        string calldata username,
        string memory pfp,
        string memory banner,
        string memory bio,
        string memory website
    ) public onlyRole(CREATOR_ROLE) returns (bool) {
        require(
            _creators[msg.sender].wallet != address(0),
            string.concat("Dexa: ", ERROR_NOT_FOUND)
        );
        require(
            bytes(name).length > 0 && bytes(username).length > 0,
            string.concat("Dexa: ", ERROR_INVALID_STRING)
        );

        address user = msg.sender;
        string memory lowerCaseName = toLower(username);
        string memory oldUsername = _creators[user].username;

        if (
            !isSameString(username, oldUsername) &&
            _usernames[lowerCaseName] == address(0)
        ) {
            delete _usernames[oldUsername];
            _usernames[lowerCaseName] = user;
            _creators[user].username = lowerCaseName;
        }

        _creators[user].name = name;
        _creators[user].pfp = pfp;
        _creators[user].banner = banner;
        _creators[user].bio = bio;
        _creators[user].website = website;
        _creators[user].updatedAt = block.timestamp;

        return true;
    }

    function addFriend(
        address user,
        address friend
    ) external onlyRole(DEXA_MESSENGER_ROLE) {
        _creators[user].friends.push(friend);
    }

    /**
     * @notice Returns a particular creator info
     * @param key This is creators address
     */
    function findCreator(address key) public view returns (Creator memory) {
        Creator memory creator = _creators[key];
        return creator;
    }

    function findAllCreators() public view returns (Creator[] memory) {
        Creator[] memory creators = new Creator[](_creatorAddresses.length);
        for (uint256 i = 0; i < _creatorAddresses.length; i++) {
            creators[i] = _creators[_creatorAddresses[i]];
        }
        return creators;
    }

    function getCreatorAddress() public view returns (address[] memory) {
        return _creatorAddresses;
    }

    function setCreators() public onlyRole(CREATOR_ROLE) returns (uint256) {
        _creatorAddresses.push(msg.sender);
        return creatorCount;
    }

    function findCreatorByUsername(
        string memory username
    ) public view returns (Creator memory) {
        address creator = _usernames[toLower(username)];
        return _creators[creator];
    }

    function addCreatorTokenData(address user, address tokenAddress) private {
        TokenData storage tokenData = _tokenData[user];
        if (!tokenData.exists[tokenAddress]) {
            tokenData.addresses.push(tokenAddress);
            tokenData.exists[tokenAddress] = true;
            emit TokenAddressAdded(user, tokenAddress);
        }
    }

    function getTokenBalances(
        address user
    ) public view returns (TokenBalance[] memory) {
        TokenData storage tokenData = _tokenData[user];
        TokenBalance[] memory balances = new TokenBalance[](
            tokenData.addresses.length
        );

        for (uint256 i = 0; i < tokenData.addresses.length; i++) {
            address tokenAddress = tokenData.addresses[i];
            balances[i] = TokenBalance({
                tokenAddress: tokenAddress,
                balance: tokenData.balances[tokenAddress]
            });
        }
        return balances;
    }

    function createTransaction(
        TransactionType txType,
        address from,
        address to,
        uint256 amount,
        uint256 fee
    ) public returns (uint) {
        if (
            !hasRole(DEXA_FEEDS_ROLE, msg.sender) &&
            !hasRole(DEXA_CREATOR_ROLE, msg.sender)
        ) {
            revert(string.concat("Dexa: ", ERROR_UNAUTHORISED_ACCESS));
        }
        _transactions[transactionCount] = Transaction(
            transactionCount,
            txType,
            payable(from),
            payable(to),
            amount,
            fee,
            block.timestamp
        );
        transactionCount++;
        return transactionCount;
    }

    function isNameFree(string memory username) public view returns (bool) {
        return _usernames[toLower(username)] == address(0);
    }

    /**
     * @notice Credits creators balance
     * @param key This is creators address
     */
    function creditBalance(
        address key,
        address tokenAddress,
        uint256 amount
    ) external onlyRole(DEXA_FEEDS_ROLE) {
        TokenData storage tokenData = _tokenData[key];
        if (!tokenData.exists[tokenAddress]) {
            addCreatorTokenData(key, tokenAddress);
        }
        tokenData.balances[tokenAddress] += amount;
        emit BalanceCredited(key, amount);
    }

    /**
     * @notice Debits creators balance
     * @param key This is creators address
     */
    function debitBalance(
        address key,
        address tokenAddress,
        uint256 amount
    ) external onlyRole(DEXA_FEEDS_ROLE) {
        TokenData storage tokenData = _tokenData[key];
        if (tokenData.exists[tokenAddress]) {
            tokenData.balances[tokenAddress] -= amount;
            emit BalanceDebited(key, amount);
        }
    }

    function creatorTransfer(
        address to,
        address tokenAddress,
        uint256 amount
    ) public onlyRole(CREATOR_ROLE) {
        TokenData storage tokenData = _tokenData[msg.sender];
        require(
            tokenData.exists[tokenAddress],
            string.concat("Dexa: ", ERROR_NOT_FOUND)
        );
        require(
            tokenData.balances[tokenAddress] >= amount,
            string.concat("Dexa: ", ERROR_INVALID_PRICE)
        );
        tokenData.balances[tokenAddress] -= amount;
        if (tokenAddress == address(0)) {
            payable(to).transfer(amount);
        } else {
            ERC20Upgradeable token = ERC20Upgradeable(tokenAddress);
            require(
                token.transfer(to, amount),
                string.concat("Dexa: ", ERROR_PROCESS_FAILED)
            );
        }
        createTransaction(TransactionType.Transfer, msg.sender, to, amount, 0);
        emit Transferred(msg.sender, to, amount);
    }

    function acceptPayment() external payable {}

    receive() external payable {}
    fallback() external payable {}
}
