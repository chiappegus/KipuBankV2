// SPDX-License-Identifier: MIT
// Compatible with OpenZeppelin Contracts ^5.4.0
pragma solidity ^0.8.27;

import {ERC20} from "@openzeppelin/contracts/token/ERC20/ERC20.sol";
import {ERC20Permit} from "@openzeppelin/contracts/token/ERC20/extensions/ERC20Permit.sol";
import {Ownable} from "@openzeppelin/contracts/access/Ownable.sol";

contract Circle is ERC20, Ownable, ERC20Permit {
    // constructor(address initialOwner)
    constructor()
        ERC20("Circle", "USDC")
        // Ownable(initialOwner)
        Ownable(msg.sender)
        ERC20Permit("Circle")
    {}
     //esta funcion permite pasar los token a la cuanta que quieras
    function mint(address to, uint256 amount) public onlyOwner {
        _mint(to, amount);
    }

     function decimals() public pure override returns (uint8) {
        return 6;
    }
}
