// SPDX-License-Identifier: GPL-3.0
/// SAFEEngine.sol -- SAFE database

// Copyright (C) 2018 Rain <rainbreak@riseup.net>
//
// This program is free software: you can redistribute it and/or modify
// it under the terms of the GNU Affero General Public License as published by
// the Free Software Foundation, either version 3 of the License, or
// (at your option) any later version.
//
// This program is distributed in the hope that it will be useful,
// but WITHOUT ANY WARRANTY; without even the implied warranty of
// MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
// GNU Affero General Public License for more details.
//
// You should have received a copy of the GNU Affero General Public License
// along with this program.  If not, see <https://www.gnu.org/licenses/>.

pragma solidity 0.8.19;

import {Math} from './utils/Math.sol';

contract SAFEEngine {
  using Math for uint256;

  // --- Auth ---
  mapping(address => uint256) public authorizedAccounts;
  /**
   * @notice Add auth to an account
   * @param account Account to add auth to
   */

  function addAuthorization(address account) external isAuthorized {
    require(contractEnabled == 1, 'SAFEEngine/contract-not-enabled');
    authorizedAccounts[account] = 1;
    emit AddAuthorization(account);
  }
  /**
   * @notice Remove auth from an account
   * @param account Account to remove auth from
   */

  function removeAuthorization(address account) external isAuthorized {
    require(contractEnabled == 1, 'SAFEEngine/contract-not-enabled');
    authorizedAccounts[account] = 0;
    emit RemoveAuthorization(account);
  }
  /**
   * @notice Checks whether msg.sender can call an authed function
   *
   */

  modifier isAuthorized() {
    require(authorizedAccounts[msg.sender] == 1, 'SAFEEngine/account-not-authorized');
    _;
  }

  // Who can transfer collateral & debt in/out of a SAFE
  mapping(address => mapping(address => uint256)) public safeRights;
  /**
   * @notice Allow an address to modify your SAFE
   * @param account Account to give SAFE permissions to
   */

  function approveSAFEModification(address account) external {
    safeRights[msg.sender][account] = 1;
    emit ApproveSAFEModification(msg.sender, account);
  }
  /**
   * @notice Deny an address the rights to modify your SAFE
   * @param account Account that is denied SAFE permissions
   */

  function denySAFEModification(address account) external {
    safeRights[msg.sender][account] = 0;
    emit DenySAFEModification(msg.sender, account);
  }
  /**
   * @notice Checks whether msg.sender has the right to modify a SAFE
   *
   */

  function canModifySAFE(address safe, address account) public view returns (bool) {
    return safe == account || safeRights[safe][account] == 1;
  }

  // --- Data ---
  struct CollateralType {
    // Total debt issued for this specific collateral type
    uint256 debtAmount; // [wad]
    // Accumulator for interest accrued on this collateral type
    uint256 accumulatedRate; // [ray]
    // Floor price at which a SAFE is allowed to generate debt
    uint256 safetyPrice; // [ray]
    // Maximum amount of debt that can be generated with this collateral type
    uint256 debtCeiling; // [rad]
    // Minimum amount of debt that must be generated by a SAFE using this collateral
    uint256 debtFloor; // [rad]
    // Price at which a SAFE gets liquidated
    uint256 liquidationPrice; // [ray]
  }

  struct SAFE {
    // Total amount of collateral locked in a SAFE
    uint256 lockedCollateral; // [wad]
    // Total amount of debt generated by a SAFE
    uint256 generatedDebt; // [wad]
  }

  // Data about each collateral type
  mapping(bytes32 => CollateralType) public collateralTypes;
  // Data about each SAFE
  mapping(bytes32 => mapping(address => SAFE)) public safes;
  // Balance of each collateral type
  mapping(bytes32 => mapping(address => uint256)) public tokenCollateral; // [wad]
  // Internal balance of system coins
  mapping(address => uint256) public coinBalance; // [rad]
  // Amount of debt held by an account. Coins & debt are like matter and antimatter. They nullify each other
  mapping(address => uint256) public debtBalance; // [rad]

  // Total amount of debt that a single safe can generate
  uint256 public safeDebtCeiling; // [wad]
  // Total amount of debt (coins) currently issued
  uint256 public globalDebt; // [rad]
  // 'Bad' debt that's not covered by collateral
  uint256 public globalUnbackedDebt; // [rad]
  // Maximum amount of debt that can be issued
  uint256 public globalDebtCeiling; // [rad]
  // Access flag, indicates whether this contract is still active
  uint256 public contractEnabled;

  // --- Events ---
  event AddAuthorization(address account);
  event RemoveAuthorization(address account);
  event ApproveSAFEModification(address sender, address account);
  event DenySAFEModification(address sender, address account);
  event InitializeCollateralType(bytes32 collateralType);
  event ModifyParameters(bytes32 parameter, uint256 data);
  event ModifyParameters(bytes32 collateralType, bytes32 parameter, uint256 data);
  event DisableContract();
  event ModifyCollateralBalance(bytes32 indexed collateralType, address indexed account, int256 wad);
  event TransferCollateral(bytes32 indexed collateralType, address indexed src, address indexed dst, uint256 wad);
  event TransferInternalCoins(address indexed src, address indexed dst, uint256 rad);
  event ModifySAFECollateralization(
    bytes32 indexed collateralType,
    address indexed safe,
    address collateralSource,
    address debtDestination,
    int256 deltaCollateral,
    int256 deltaDebt,
    uint256 lockedCollateral,
    uint256 generatedDebt,
    uint256 globalDebt
  );
  event TransferSAFECollateralAndDebt(
    bytes32 indexed collateralType,
    address indexed src,
    address indexed dst,
    int256 deltaCollateral,
    int256 deltaDebt,
    uint256 srcLockedCollateral,
    uint256 srcGeneratedDebt,
    uint256 dstLockedCollateral,
    uint256 dstGeneratedDebt
  );
  event ConfiscateSAFECollateralAndDebt(
    bytes32 indexed collateralType,
    address indexed safe,
    address collateralCounterparty,
    address debtCounterparty,
    int256 deltaCollateral,
    int256 deltaDebt,
    uint256 globalUnbackedDebt
  );
  event SettleDebt(
    address indexed account,
    uint256 rad,
    uint256 debtBalance,
    uint256 coinBalance,
    uint256 globalUnbackedDebt,
    uint256 globalDebt
  );
  event CreateUnbackedDebt(
    address indexed debtDestination,
    address indexed coinDestination,
    uint256 rad,
    uint256 debtDstBalance,
    uint256 coinDstBalance,
    uint256 globalUnbackedDebt,
    uint256 globalDebt
  );
  event UpdateAccumulatedRate(
    bytes32 indexed collateralType,
    address surplusDst,
    int256 rateMultiplier,
    uint256 dstCoinBalance,
    uint256 globalDebt
  );

  // --- Init ---
  constructor() {
    authorizedAccounts[msg.sender] = 1;
    safeDebtCeiling = type(uint256).max;
    contractEnabled = 1;
    emit AddAuthorization(msg.sender);
    emit ModifyParameters('safeDebtCeiling', type(uint256).max);
  }

  // --- Administration ---
  /**
   * @notice Creates a brand new collateral type
   * @param collateralType Collateral type name (e.g ETH-A, TBTC-B)
   */
  function initializeCollateralType(bytes32 collateralType) external isAuthorized {
    require(collateralTypes[collateralType].accumulatedRate == 0, 'SAFEEngine/collateral-type-already-exists');
    collateralTypes[collateralType].accumulatedRate = 10 ** 27;
    emit InitializeCollateralType(collateralType);
  }
  /**
   * @notice Modify general uint256 params
   * @param parameter The name of the parameter modified
   * @param data New value for the parameter
   */

  function modifyParameters(bytes32 parameter, uint256 data) external isAuthorized {
    require(contractEnabled == 1, 'SAFEEngine/contract-not-enabled');
    if (parameter == 'globalDebtCeiling') globalDebtCeiling = data;
    else if (parameter == 'safeDebtCeiling') safeDebtCeiling = data;
    else revert('SAFEEngine/modify-unrecognized-param');
    emit ModifyParameters(parameter, data);
  }
  /**
   * @notice Modify collateral specific params
   * @param collateralType Collateral type we modify params for
   * @param parameter The name of the parameter modified
   * @param data New value for the parameter
   */

  function modifyParameters(bytes32 collateralType, bytes32 parameter, uint256 data) external isAuthorized {
    require(contractEnabled == 1, 'SAFEEngine/contract-not-enabled');
    if (parameter == 'safetyPrice') collateralTypes[collateralType].safetyPrice = data;
    else if (parameter == 'liquidationPrice') collateralTypes[collateralType].liquidationPrice = data;
    else if (parameter == 'debtCeiling') collateralTypes[collateralType].debtCeiling = data;
    else if (parameter == 'debtFloor') collateralTypes[collateralType].debtFloor = data;
    else revert('SAFEEngine/modify-unrecognized-param');
    emit ModifyParameters(collateralType, parameter, data);
  }
  /**
   * @notice Disable this contract (normally called by GlobalSettlement)
   */

  function disableContract() external isAuthorized {
    contractEnabled = 0;
    emit DisableContract();
  }

  // --- Fungibility ---
  /**
   * @notice Join/exit collateral into and and out of the system
   * @param collateralType Collateral type to join/exit
   * @param account Account that gets credited/debited
   * @param wad Amount of collateral
   */
  function modifyCollateralBalance(bytes32 collateralType, address account, int256 wad) external isAuthorized {
    tokenCollateral[collateralType][account] = tokenCollateral[collateralType][account].add(wad);
    emit ModifyCollateralBalance(collateralType, account, wad);
  }
  /**
   * @notice Transfer collateral between accounts
   * @param collateralType Collateral type transferred
   * @param src Collateral source
   * @param dst Collateral destination
   * @param wad Amount of collateral transferred
   */

  function transferCollateral(bytes32 collateralType, address src, address dst, uint256 wad) external {
    require(canModifySAFE(src, msg.sender), 'SAFEEngine/not-allowed');
    tokenCollateral[collateralType][src] = tokenCollateral[collateralType][src] - wad;
    tokenCollateral[collateralType][dst] = tokenCollateral[collateralType][dst] + wad;
    emit TransferCollateral(collateralType, src, dst, wad);
  }
  /**
   * @notice Transfer internal coins (does not affect external balances from Coin.sol)
   * @param src Coins source
   * @param dst Coins destination
   * @param rad Amount of coins transferred
   */

  function transferInternalCoins(address src, address dst, uint256 rad) external {
    require(canModifySAFE(src, msg.sender), 'SAFEEngine/not-allowed');
    coinBalance[src] = coinBalance[src] - rad;
    coinBalance[dst] = coinBalance[dst] + rad;
    emit TransferInternalCoins(src, dst, rad);
  }

  // --- SAFE Manipulation ---
  /**
   * @notice Add/remove collateral or put back/generate more debt in a SAFE
   * @param collateralType Type of collateral to withdraw/deposit in and from the SAFE
   * @param safe Target SAFE
   * @param collateralSource Account we take collateral from/put collateral into
   * @param debtDestination Account from which we credit/debit coins and debt
   * @param deltaCollateral Amount of collateral added/extract from the SAFE (wad)
   * @param deltaDebt Amount of debt to generate/repay (wad)
   */
  function modifySAFECollateralization(
    bytes32 collateralType,
    address safe,
    address collateralSource,
    address debtDestination,
    int256 deltaCollateral,
    int256 deltaDebt
  ) external {
    // system is live
    require(contractEnabled == 1, 'SAFEEngine/contract-not-enabled');

    SAFE memory safeData = safes[collateralType][safe];
    CollateralType memory collateralTypeData = collateralTypes[collateralType];
    // collateral type has been initialised
    require(collateralTypeData.accumulatedRate != 0, 'SAFEEngine/collateral-type-not-initialized');

    safeData.lockedCollateral = safeData.lockedCollateral.add(deltaCollateral);
    safeData.generatedDebt = safeData.generatedDebt.add(deltaDebt);
    collateralTypeData.debtAmount = collateralTypeData.debtAmount.add(deltaDebt);

    int256 deltaAdjustedDebt = collateralTypeData.accumulatedRate.mul(deltaDebt);
    uint256 totalDebtIssued = collateralTypeData.accumulatedRate * safeData.generatedDebt;
    globalDebt = globalDebt.add(deltaAdjustedDebt);

    // either debt has decreased, or debt ceilings are not exceeded
    require(
      deltaDebt <= 0
        || (
          collateralTypeData.debtAmount * collateralTypeData.accumulatedRate <= collateralTypeData.debtCeiling
            && globalDebt <= globalDebtCeiling
        ),
      'SAFEEngine/ceiling-exceeded'
    );
    // safe is either less risky than before, or it is safe
    require(
      (deltaDebt <= 0 && deltaCollateral >= 0)
        || totalDebtIssued <= safeData.lockedCollateral * collateralTypeData.safetyPrice,
      'SAFEEngine/not-safe'
    );

    // safe is either more safe, or the owner consents
    require(
      (deltaDebt <= 0 && deltaCollateral >= 0) || canModifySAFE(safe, msg.sender),
      'SAFEEngine/not-allowed-to-modify-safe'
    );
    // collateral src consents
    require(
      deltaCollateral <= 0 || canModifySAFE(collateralSource, msg.sender), 'SAFEEngine/not-allowed-collateral-src'
    );
    // debt dst consents
    require(deltaDebt >= 0 || canModifySAFE(debtDestination, msg.sender), 'SAFEEngine/not-allowed-debt-dst');

    // safe has no debt, or a non-dusty amount
    require(safeData.generatedDebt == 0 || totalDebtIssued >= collateralTypeData.debtFloor, 'SAFEEngine/dust');

    // safe didn't go above the safe debt limit
    if (deltaDebt > 0) {
      require(safeData.generatedDebt <= safeDebtCeiling, 'SAFEEngine/above-debt-limit');
    }

    tokenCollateral[collateralType][collateralSource] =
      tokenCollateral[collateralType][collateralSource].sub(deltaCollateral);

    coinBalance[debtDestination] = coinBalance[debtDestination].add(deltaAdjustedDebt);

    safes[collateralType][safe] = safeData;
    collateralTypes[collateralType] = collateralTypeData;

    emit ModifySAFECollateralization(
      collateralType,
      safe,
      collateralSource,
      debtDestination,
      deltaCollateral,
      deltaDebt,
      safeData.lockedCollateral,
      safeData.generatedDebt,
      globalDebt
    );
  }

  // --- SAFE Fungibility ---
  /**
   * @notice Transfer collateral and/or debt between SAFEs
   * @param collateralType Collateral type transferred between SAFEs
   * @param src Source SAFE
   * @param dst Destination SAFE
   * @param deltaCollateral Amount of collateral to take/add into src and give/take from dst (wad)
   * @param deltaDebt Amount of debt to take/add into src and give/take from dst (wad)
   */
  function transferSAFECollateralAndDebt(
    bytes32 collateralType,
    address src,
    address dst,
    int256 deltaCollateral,
    int256 deltaDebt
  ) external {
    SAFE storage srcSAFE = safes[collateralType][src];
    SAFE storage dstSAFE = safes[collateralType][dst];
    CollateralType storage collateralType_ = collateralTypes[collateralType];

    srcSAFE.lockedCollateral = srcSAFE.lockedCollateral.sub(deltaCollateral);
    srcSAFE.generatedDebt = srcSAFE.generatedDebt.sub(deltaDebt);
    dstSAFE.lockedCollateral = dstSAFE.lockedCollateral.add(deltaCollateral);
    dstSAFE.generatedDebt = dstSAFE.generatedDebt.add(deltaDebt);

    uint256 srcTotalDebtIssued = srcSAFE.generatedDebt * collateralType_.accumulatedRate;
    uint256 dstTotalDebtIssued = dstSAFE.generatedDebt * collateralType_.accumulatedRate;

    // both sides consent
    require(canModifySAFE(src, msg.sender) && canModifySAFE(dst, msg.sender), 'SAFEEngine/not-allowed');

    // both sides safe
    require(srcTotalDebtIssued <= srcSAFE.lockedCollateral * collateralType_.safetyPrice, 'SAFEEngine/not-safe-src');
    require(dstTotalDebtIssued <= dstSAFE.lockedCollateral * collateralType_.safetyPrice, 'SAFEEngine/not-safe-dst');

    // both sides non-dusty
    require(srcTotalDebtIssued >= collateralType_.debtFloor || srcSAFE.generatedDebt == 0, 'SAFEEngine/dust-src');
    require(dstTotalDebtIssued >= collateralType_.debtFloor || dstSAFE.generatedDebt == 0, 'SAFEEngine/dust-dst');

    emit TransferSAFECollateralAndDebt(
      collateralType,
      src,
      dst,
      deltaCollateral,
      deltaDebt,
      srcSAFE.lockedCollateral,
      srcSAFE.generatedDebt,
      dstSAFE.lockedCollateral,
      dstSAFE.generatedDebt
    );
  }

  // --- SAFE Confiscation ---
  /**
   * @notice Normally used by the LiquidationEngine in order to confiscate collateral and
   *      debt from a SAFE and give them to someone else
   * @param collateralType Collateral type the SAFE has locked inside
   * @param safe Target SAFE
   * @param collateralCounterparty Who we take/give collateral to
   * @param debtCounterparty Who we take/give debt to
   * @param deltaCollateral Amount of collateral taken/added into the SAFE (wad)
   * @param deltaDebt Amount of debt taken/added into the SAFE (wad)
   */
  function confiscateSAFECollateralAndDebt(
    bytes32 collateralType,
    address safe,
    address collateralCounterparty,
    address debtCounterparty,
    int256 deltaCollateral,
    int256 deltaDebt
  ) external isAuthorized {
    SAFE storage safe_ = safes[collateralType][safe];
    CollateralType storage collateralType_ = collateralTypes[collateralType];

    safe_.lockedCollateral = safe_.lockedCollateral.add(deltaCollateral);
    safe_.generatedDebt = safe_.generatedDebt.add(deltaDebt);
    collateralType_.debtAmount = collateralType_.debtAmount.add(deltaDebt);

    int256 deltaTotalIssuedDebt = collateralType_.accumulatedRate.mul(deltaDebt);

    tokenCollateral[collateralType][collateralCounterparty] =
      tokenCollateral[collateralType][collateralCounterparty].sub(deltaCollateral);
    debtBalance[debtCounterparty] = debtBalance[debtCounterparty].sub(deltaTotalIssuedDebt);
    globalUnbackedDebt = globalUnbackedDebt.sub(deltaTotalIssuedDebt);

    emit ConfiscateSAFECollateralAndDebt(
      collateralType, safe, collateralCounterparty, debtCounterparty, deltaCollateral, deltaDebt, globalUnbackedDebt
    );
  }

  // --- Settlement ---
  /**
   * @notice Nullify an amount of coins with an equal amount of debt
   * @param rad Amount of debt & coins to destroy
   */
  function settleDebt(uint256 rad) external {
    address account = msg.sender;
    debtBalance[account] = debtBalance[account] - rad;
    coinBalance[account] = coinBalance[account] - rad;
    globalUnbackedDebt = globalUnbackedDebt - rad;
    globalDebt = globalDebt - rad;
    emit SettleDebt(account, rad, debtBalance[account], coinBalance[account], globalUnbackedDebt, globalDebt);
  }
  /**
   * @notice Usually called by CoinSavingsAccount in order to create unbacked debt
   * @param debtDestination Usually AccountingEngine that can settle uncovered debt with surplus
   * @param coinDestination Usually CoinSavingsAccount that passes the new coins to depositors
   * @param rad Amount of debt to create
   */

  function createUnbackedDebt(address debtDestination, address coinDestination, uint256 rad) external isAuthorized {
    debtBalance[debtDestination] = debtBalance[debtDestination] + rad;
    coinBalance[coinDestination] = coinBalance[coinDestination] + rad;
    globalUnbackedDebt = globalUnbackedDebt + rad;
    globalDebt = globalDebt + rad;
    emit CreateUnbackedDebt(
      debtDestination,
      coinDestination,
      rad,
      debtBalance[debtDestination],
      coinBalance[coinDestination],
      globalUnbackedDebt,
      globalDebt
    );
  }

  // --- Rates ---
  /**
   * @notice Usually called by TaxCollector in order to accrue interest on a specific collateral type
   * @param collateralType Collateral type we accrue interest for
   * @param surplusDst Destination for the newly created surplus
   * @param rateMultiplier Multiplier applied to the debtAmount in order to calculate the surplus [ray]
   */
  function updateAccumulatedRate(
    bytes32 collateralType,
    address surplusDst,
    int256 rateMultiplier
  ) external isAuthorized {
    require(contractEnabled == 1, 'SAFEEngine/contract-not-enabled');
    CollateralType storage collateralType_ = collateralTypes[collateralType];
    collateralType_.accumulatedRate = collateralType_.accumulatedRate.add(rateMultiplier);
    int256 deltaSurplus = collateralType_.debtAmount.mul(rateMultiplier);
    coinBalance[surplusDst] = coinBalance[surplusDst].add(deltaSurplus);
    globalDebt = globalDebt.add(deltaSurplus);
    emit UpdateAccumulatedRate(collateralType, surplusDst, rateMultiplier, coinBalance[surplusDst], globalDebt);
  }
}