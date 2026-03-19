// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

/// @title ICreature
/// @notice Interface that Ecosystem, GenePool, and Factory use to
///         interact with deployed Creature instances.
interface ICreature {
    struct DNA {
        uint8 targetChainId; // Polkadot destination index: 0=AssetHub, 1=Moonbeam, 2=Acala, 3=Astar, 4=HydraDX, 5=Bifrost
        uint8 poolType; // 0=AMM_LP, 1=LENDING, 2=STAKING, 3=VAULT, 4=STABLE_SWAP, 5=RESTAKING
        uint16 allocationRatio; // basis points 1000-10000
        uint16 rebalanceThreshold; // basis points 100-2000
        uint16 maxSlippage; // basis points 10-500
        uint16 yieldFloor; // basis points annualized 100-5000
        uint8 riskCeiling; // 1-10
        uint8 entryTiming; // epoch offset 0-5
        uint8 exitTiming; // epochs to hold 1-10
        uint16 hedgeRatio; // basis points 0-5000
    }

    function initialize(
        DNA memory _dna,
        uint256 _generation,
        address _parent1,
        address _parent2,
        uint256 _birthEpoch,
        address _ecosystem,
        address _stablecoin,
        address _xcmPrecompile
    ) external;

    function feed() external;
    function harvest() external;
    function kill() external;
    function receiveCapital(uint256 amount) external;
    function returnCapital(uint256 amount) external;
    function getDNA() external view returns (DNA memory);
    function getEncodedDNA() external view returns (bytes memory);
    function getPerformance()
        external
        view
        returns (
            int256 lastReturn,
            int256 cumulativeReturn,
            uint256 epochsSurvived,
            int256 maxDrawdown,
            uint256 balance
        );
    function isAlive() external view returns (bool);
    function generation() external view returns (uint256);
    function parent1() external view returns (address);
    function parent2() external view returns (address);
    function birthEpoch() external view returns (uint256);
}
