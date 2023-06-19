# XenGame

XenGame is an open-source decentralized game built on the Ethereum blockchain. It allows players to participate in key-based rounds and win Ether. The project encourages other developers to utilize the provided NFT registry and Xen Burn contracts for their own open-source projects related to Xen.

## System Setup

To set up the XenGame environment, follow these steps:

1. Install Solidity and the required dependencies.
2. Clone the XenGame repository from GitHub.
3. Compile the Solidity contracts using a compatible compiler.
4. Deploy the contracts on the Ethereum blockchain using a development network or one of your choice.
5. Interact with the deployed contracts through their respective addresses.

## Contracts

The XenGame project consists of three contracts:

1. XenGame: The main contract that handles the game logic, key purchases, rewards distribution, and round management.
2. NFTRegistry: A contract that manages the registration of NFTs for use within the XenGame ecosystem.
3. XenBurn: A contract to burn Ether as part of the game's mechanics.

Developers are encouraged to utilize the NFTRegistry and XenBurn contracts for their own open-source projects related to Xen.

## Testing

The XenGame project uses Foundry for testing. To run the tests, follow these steps:

1. Install Foundry and the required dependencies.
2. Run the Foundry test command to execute all the unit tests and ensure the proper functioning of the contracts.

```
foundry test
```

Make sure you have a local Ethereum development network running or specify a different network in the configuration.

## Contributing

Contributions to XenGame are welcome! If you have any ideas, bug fixes, or feature improvements, feel free to submit a pull request. Please make sure to follow the project's coding conventions and include relevant tests.

## License

XenGame is open-source software released under the [MIT License](LICENSE). Feel free to use, modify, and distribute the code according to the terms of the license.