// SPDX-License-Identifier: MIT
pragma solidity ^0.8.9;

import "@openzeppelin/contracts-upgradeable/proxy/utils/Initializable.sol";
import "@openzeppelin/contracts-upgradeable/token/ERC1155/ERC1155Upgradeable.sol";
import "@openzeppelin/contracts-upgradeable/access/OwnableUpgradeable.sol";
import "@openzeppelin/contracts-upgradeable/access/AccessControlUpgradeable.sol";
import "@openzeppelin/contracts-upgradeable/token/ERC1155/extensions/ERC1155PausableUpgradeable.sol";
import "@openzeppelin/contracts-upgradeable/token/ERC1155/extensions/ERC1155SupplyUpgradeable.sol";

contract DexaFeed is
    Initializable,
    ERC1155Upgradeable,
    OwnableUpgradeable,
    ERC1155PausableUpgradeable,
    ERC1155SupplyUpgradeable,
    AccessControlUpgradeable
{
    /**
     * @notice Initialize DexaFeed Token
     * @param _dexa Dexa contract address
     */
    function init_dexa_feed(address _dexa) public initializer {
        __ERC1155_init("");
        __Ownable_init(_dexa);
        __ERC1155Pausable_init();
        __ERC1155Supply_init();
    }

    /**
     * -----------------------Admin Functions---------------------------
     * -----------------------------------------------------------------
     */

    function pause() public onlyOwner {
        _pause();
    }

    function unpause() public onlyOwner {
        _unpause();
    }

    function mint(
        address account,
        uint256 id,
        uint256 amount,
        bytes memory data,
        string memory tokenURI
    ) external onlyOwner {
        _mint(account, id, amount, data);
        _setURI(tokenURI);
    }

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
