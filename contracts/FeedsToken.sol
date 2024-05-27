// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

import "./DexaBase.sol";
import "@openzeppelin/contracts-upgradeable/token/ERC1155/ERC1155Upgradeable.sol";
import "@openzeppelin/contracts-upgradeable/token/ERC20/ERC20Upgradeable.sol";

contract FeedsToken is DexaBase, ERC1155Upgradeable {
    /**
     * @notice Initialize Feeds Token
     */
    function init_feed_token(address _admin) public initializer {
        __ERC1155_init("https://gnfd-testnet-sp1.bnbchain.org/view/dexa/metadata/{id}.json");
        __AccessControl_init();
        DexaBase.init_dexa_base(_admin);
    }

    function init_roles(
        address _dexaCreator,
        address _dexaFeeds
    ) external onlyRole(DEFAULT_ADMIN_ROLE) {
        _grantRole(DEXA_CREATOR_ROLE, _dexaCreator);
        _grantRole(DEXA_FEEDS_ROLE, _dexaFeeds);
    }

    function transfer(
        address from,
        address to,
        uint256 tokenId,
        uint256 value,
        bytes memory data
    ) public onlyRole(DEXA_FEEDS_ROLE) {
        _safeTransferFrom(from, to, tokenId, value, data);
    }

    function mint(
        address minter,
        uint256 tokenId,
        uint256 limit,
        bytes memory data
    ) public onlyRole(DEXA_FEEDS_ROLE) {
        _mint(minter, tokenId, limit, data);
    }

    function setTokenURI(
        string memory uri
    ) public onlyRole(DEFAULT_ADMIN_ROLE) {
        _setURI(uri);
    }

    function mintBatch(
        address to,
        uint256[] memory ids,
        uint256[] memory amounts,
        bytes memory data
    ) public onlyRole(DEXA_FEEDS_ROLE) {
        _mintBatch(to, ids, amounts, data);
    }

    function _update(
        address from,
        address to,
        uint256[] memory ids,
        uint256[] memory values
    ) internal override(ERC1155Upgradeable) {
        super._update(from, to, ids, values);
    }

    function supportsInterface(
        bytes4 interfaceId
    )
        public
        view
        override(ERC1155Upgradeable, AccessControlUpgradeable)
        returns (bool)
    {
        return super.supportsInterface(interfaceId);
    }
}
