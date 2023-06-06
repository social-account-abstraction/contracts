# Social Recovery Contracts

Implementation of contracts for [ERC-4337](https://eips.ethereum.org/EIPS/eip-4337) account abstraction via alternative mempool.

Additional functions was added:
```
initSocialRecovery(
    bytes32[] calldata newSocialRecoveryAgents, 
    address[] calldata newAlertAgents
) external onlyOwner
```
```
freeze(
    string calldata reason
) external onlyAlertAgentsOrOwner
```
```
unfreeze(
    bytes32[] calldata oneTimeSocialRecoveryAgentsKeys, 
    bytes32[] calldata newSocialRecoveryAgents, 
    bytes32 salt, 
    address[] calldata newAlertAgents, 
    address newOwner
) external
```

Additional events was added:
```
event OwnerTransferred(address indexed newOwner);
event NewAlertAgents(address[] newAlertAgents);
event NewSocialRecoveryAgents(bytes32[] newSocialRecoveryAgents);
event Frozen(address indexed alertAgent, string reasson);
```
# Resources

[Vitalik's post on account abstraction without Ethereum protocol changes](https://medium.com/infinitism/erc-4337-account-abstraction-without-ethereum-protocol-changes-d75c9d94dc4a)

[Discord server](http://discord.gg/fbDyENb6Y9)

[Bundler reference implementation](https://github.com/eth-infinitism/bundler)

[Bundler specification test suite](https://github.com/eth-infinitism/bundler-spec-tests)
