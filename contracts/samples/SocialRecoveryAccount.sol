// SPDX-License-Identifier: GPL-3.0
pragma solidity ^0.8.12;

/* solhint-disable avoid-low-level-calls */
/* solhint-disable no-inline-assembly */
/* solhint-disable reason-string */

import "@openzeppelin/contracts/utils/cryptography/ECDSA.sol";
import "@openzeppelin/contracts/proxy/utils/Initializable.sol";
import "@openzeppelin/contracts/proxy/utils/UUPSUpgradeable.sol";

import "../core/BaseAccount.sol";
import "./callback/TokenCallbackHandler.sol";


contract SocialRecoveryAccount is BaseAccount, TokenCallbackHandler, UUPSUpgradeable, Initializable {
  using ECDSA for bytes32;

  bool public frozen;
  address public owner;
  address[] public alertAgents;
  bytes32[] public socialRecoveryAgents;

  IEntryPoint private immutable _entryPoint;

  event SocialRecoveryAccountInitialized(IEntryPoint indexed entryPoint, address indexed owner);
  event OwnerTransferred(address indexed newOwner);
  event NewAlertAgents(address[] newAlertAgents);
  event NewSocialRecoveryAgents(bytes32[] newSocialRecoveryAgents);
  event Frozen(address indexed alertAgent, string reasson);

  modifier onlyOwner() {
    _onlyOwner();
    _;
  }
  modifier onlyAlertAgentsOrOwner() {
    _onlyAlertAgentsOrOwner();
    _;
  }

  /// @inheritdoc BaseAccount
  function entryPoint() public view virtual override returns (IEntryPoint) {
    return _entryPoint;
  }


  // solhint-disable-next-line no-empty-blocks
  receive() external payable {}

  constructor(IEntryPoint anEntryPoint) {
    _entryPoint = anEntryPoint;
    _disableInitializers();
  }

  function _onlyDefrosted() internal view {
    require(!frozen, "only defrosted");
  }

  function _onlyOwner() internal view {
    //directly from EOA owner, or through the account itself (which gets redirected through execute())
    require(msg.sender == owner || msg.sender == address(this), "only owner");
  }

  function _onlyAlertAgentsOrOwner() internal view {
    bool fromAlertAgent = false;
    for (uint256 i = 0; i < alertAgents.length; i++) {
      if (alertAgents[i] == msg.sender) {
        fromAlertAgent = true;
      }
    }
    require(msg.sender == owner || msg.sender == address(this) || fromAlertAgent, "only owner or alert agent");
  }

  /**
   * execute a transaction (called directly from owner, or by entryPoint)
   */
  function execute(address dest, uint256 value, bytes calldata func) external {
    _onlyDefrosted();
    _requireFromEntryPointOrOwner();
    _call(dest, value, func);
  }

  /**
   * execute a sequence of transactions
   */
  function executeBatch(address[] calldata dest, bytes[] calldata func) external {
    _onlyDefrosted();
    _requireFromEntryPointOrOwner();
    require(dest.length == func.length, "wrong array lengths");
    for (uint256 i = 0; i < dest.length; i++) {
      _call(dest[i], 0, func[i]);
    }
  }

  /**
   * @dev The _entryPoint member is immutable, to reduce gas consumption.  To upgrade EntryPoint,
     * a new implementation of SocialRecoveryAccount must be deployed with the new EntryPoint address, then upgrading
      * the implementation by calling `upgradeTo()`
     */
  function initialize(address anOwner) public virtual initializer {
    _initialize(anOwner);
  }

  function _initialize(address anOwner) internal virtual {
    owner = anOwner;
    emit SocialRecoveryAccountInitialized(_entryPoint, owner);
  }

  // Require the function call went through EntryPoint or owner
  function _requireFromEntryPointOrOwner() internal view {
    require(msg.sender == address(entryPoint()) || msg.sender == owner, "account: not Owner or EntryPoint");
  }

  /// implement template method of BaseAccount
  function _validateSignature(UserOperation calldata userOp, bytes32 userOpHash)
  internal override virtual returns (uint256 validationData) {
    bytes32 hash = userOpHash.toEthSignedMessageHash();
    if (owner != hash.recover(userOp.signature))
      return SIG_VALIDATION_FAILED;
    return 0;
  }

  function _call(address target, uint256 value, bytes memory data) internal {
    (bool success, bytes memory result) = target.call{value : value}(data);
    if (!success) {
      assembly {
        revert(add(result, 32), mload(result))
      }
    }
  }

  /**
   * check current account deposit in the entryPoint
   */
  function getDeposit() public view returns (uint256) {
    return entryPoint().balanceOf(address(this));
  }

  /**
   * deposit more funds for this account in the entryPoint
   */
  function addDeposit() public payable {
    entryPoint().depositTo{value : msg.value}(address(this));
  }

  /**
   * withdraw value from the account's deposit
   * @param withdrawAddress target to send to
     * @param amount to withdraw
     */
  function withdrawDepositTo(address payable withdrawAddress, uint256 amount) public onlyOwner {
    _onlyDefrosted();
    entryPoint().withdrawTo(withdrawAddress, amount);
  }

  function _authorizeUpgrade(address newImplementation) internal view override {
    (newImplementation);
    _onlyDefrosted();
    _onlyOwner();
  }

  function initSocialRecovery(
    bytes32[] calldata newSocialRecoveryAgents,
    address[] calldata newAlertAgents
  ) external onlyOwner {
    require(socialRecoveryAgents.length == 0 && alertAgents.length == 0, "already init");

    require(newAlertAgents.length != 0, "empty alert agents");
    require(newSocialRecoveryAgents.length != 0, "empty social recovery agents");

    alertAgents = newAlertAgents;
    emit NewAlertAgents(newAlertAgents);

    socialRecoveryAgents = newSocialRecoveryAgents;
    emit NewSocialRecoveryAgents(newSocialRecoveryAgents);
  }

  function _checkOneTimeSocialRecoveryAgentsKeys(
    bytes32[] calldata oneTimeSocialRecoveryAgentsKeys,
    bytes32[] calldata newSocialRecoveryAgents,
    bytes32 salt
  ) private {
    require(oneTimeSocialRecoveryAgentsKeys.length == socialRecoveryAgents.length, "wrong SRA count");

    for (uint256 i = 0; i < oneTimeSocialRecoveryAgentsKeys.length; i++) {
      bytes32 hash = keccak256(abi.encode(
          keccak256('SocialRecovery(bytes32 salt,bytes32 key)'),
          salt,
          oneTimeSocialRecoveryAgentsKeys[i]
        ));
      require(hash == socialRecoveryAgents[i], "wrong SRA key");
    }

    socialRecoveryAgents = newSocialRecoveryAgents;
    emit NewSocialRecoveryAgents(newSocialRecoveryAgents);
  }

  /**
   * @notice  can change sign key, can change alert agents, always change SRA keys and always unfreeze.
   * @dev     used for social recovery.
  */
  function unfreeze(
    bytes32[] calldata oneTimeSocialRecoveryAgentsKeys,
    bytes32[] calldata newSocialRecoveryAgents,
    bytes32 salt,
    address[] calldata newAlertAgents,
    address newOwner
  ) external {
    _checkOneTimeSocialRecoveryAgentsKeys(oneTimeSocialRecoveryAgentsKeys, newSocialRecoveryAgents, salt);

    if (newAlertAgents.length != 0) {
      alertAgents = newAlertAgents;
      emit NewAlertAgents(newAlertAgents);
    }
    if (newOwner != address(0) && newOwner != owner) {
      owner = newOwner;
      emit OwnerTransferred(newOwner);
    }

    frozen = false;
  }

  function freeze(string calldata reason) external onlyAlertAgentsOrOwner {
    frozen = true;
    emit Frozen(msg.sender, reason);
  }
}

