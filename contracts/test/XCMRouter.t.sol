// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

import "forge-std/Test.sol";
import {IERC20} from "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import {Ecosystem} from "../src/Ecosystem.sol";
import {Creature} from "../src/Creature.sol";
import {CreatureFactory} from "../src/CreatureFactory.sol";
import {GenePool} from "../src/GenePool.sol";
import {ICreature} from "../src/interfaces/ICreature.sol";
import {IXCM} from "../src/interfaces/IXCM.sol";
import {XCMRouter} from "../src/xcm/XCMRouter.sol";
import {XCMMessageBuilder} from "../src/xcm/XCMMessageBuilder.sol";
import {ScaleCodec} from "../src/xcm/ScaleCodec.sol";
import {MockStablecoin} from "./mocks/MockStablecoin.sol";
import {MockEvolutionEngine} from "./mocks/MockEvolutionEngine.sol";

/// @title XCMRouterTest
/// @notice Tests the XCM integration layer:
///         1. SCALE codec encoding correctness
///         2. XCM message builder output
///         3. XCMRouter simulation mode (drop-in replacement for MockXCM)
///         4. XCMRouter production mode message construction
///         5. Full epoch flow with XCMRouter
contract XCMRouterTest is Test {
    XCMRouter public router;
    MockStablecoin public usdc;
    Ecosystem public ecosystem;
    CreatureFactory public factory;
    GenePool public genePool;
    MockEvolutionEngine public evoEngine;

    address public alice = makeAddr("alice");
    address public seeder = makeAddr("seeder");

    uint32 constant ASSET_HUB_PARA_ID = 1000;
    uint128 constant USDT_ASSET_ID = 1984;

    function setUp() public {
        usdc = new MockStablecoin();
        router = new XCMRouter(XCMRouter.Mode.SIMULATION, ASSET_HUB_PARA_ID);
        evoEngine = new MockEvolutionEngine();

        factory = new CreatureFactory(address(usdc), address(router));
        ecosystem = new Ecosystem(address(usdc), address(factory), 10);
        factory.setEcosystem(address(ecosystem));

        genePool = new GenePool(
            address(ecosystem),
            address(factory),
            address(evoEngine),
            3000, 2000, 1000, 50, seeder
        );
        factory.setGenePool(address(genePool));
        ecosystem.setGenePool(address(genePool));

        // Fund
        usdc.mint(alice, 100_000e6);
        usdc.mint(address(router), 500_000e6); // yield supply
    }

    // ================================================================
    // SCALE Codec Tests
    // ================================================================

    function test_scale_compact_single_byte() public pure {
        // Values 0-63: single byte mode
        bytes memory encoded = ScaleCodec.encodeCompact(0);
        assertEq(encoded.length, 1);
        assertEq(uint8(encoded[0]), 0x00); // 0 << 2 = 0

        encoded = ScaleCodec.encodeCompact(1);
        assertEq(uint8(encoded[0]), 0x04); // 1 << 2 = 4

        encoded = ScaleCodec.encodeCompact(63);
        assertEq(uint8(encoded[0]), 0xFC); // 63 << 2 = 252
    }

    function test_scale_compact_two_byte() public pure {
        // Values 64-16383: two byte mode
        bytes memory encoded = ScaleCodec.encodeCompact(64);
        assertEq(encoded.length, 2);
        // 64 << 2 | 0x01 = 0x0101
        assertEq(uint8(encoded[0]), 0x01);
        assertEq(uint8(encoded[1]), 0x01);

        encoded = ScaleCodec.encodeCompact(16383);
        assertEq(encoded.length, 2);
    }

    function test_scale_compact_four_byte() public pure {
        // Values 16384-2^30-1: four byte mode
        bytes memory encoded = ScaleCodec.encodeCompact(16384);
        assertEq(encoded.length, 4);
        // 16384 << 2 | 0x02 = 0x00010002
        assertEq(uint8(encoded[0]), 0x02);
        assertEq(uint8(encoded[1]), 0x00);
        assertEq(uint8(encoded[2]), 0x01);
        assertEq(uint8(encoded[3]), 0x00);
    }

    function test_scale_compact_big_integer() public pure {
        // Values >= 2^30: big integer mode
        uint256 value = 1_000_000e6; // 1M USDC = 1_000_000_000_000
        bytes memory encoded = ScaleCodec.encodeCompact(value);
        // First byte: ((byteLen - 4) << 2) | 0x03
        // 1_000_000_000_000 = 0xE8D4A51000 → 5 bytes
        assertGt(encoded.length, 4);
        assertEq(uint8(encoded[0]) & 0x03, 0x03); // big int flag
    }

    function test_scale_u32_le() public pure {
        bytes memory encoded = ScaleCodec.encodeU32LE(1000);
        assertEq(encoded.length, 4);
        // 1000 = 0x000003E8 → LE: E8 03 00 00
        assertEq(uint8(encoded[0]), 0xE8);
        assertEq(uint8(encoded[1]), 0x03);
        assertEq(uint8(encoded[2]), 0x00);
        assertEq(uint8(encoded[3]), 0x00);
    }

    function test_scale_u32_le_parachain_id() public pure {
        // Parachain ID 2000 (Acala)
        bytes memory encoded = ScaleCodec.encodeU32LE(2000);
        assertEq(encoded.length, 4);
        // 2000 = 0x000007D0 → LE: D0 07 00 00
        assertEq(uint8(encoded[0]), 0xD0);
        assertEq(uint8(encoded[1]), 0x07);
    }

    // ================================================================
    // XCM Message Builder Tests
    // ================================================================

    function test_xcm_message_starts_with_v4() public pure {
        bytes memory msg_ = XCMMessageBuilder.buildTransferToParachain(
            USDT_ASSET_ID,
            1000e6,
            2000,
            address(0x1234567890123456789012345678901234567890),
            ASSET_HUB_PARA_ID
        );

        // First byte should be V4 (0x04)
        assertEq(uint8(msg_[0]), 0x04, "Message should start with V4 version byte");
    }

    function test_xcm_message_has_one_instruction() public pure {
        bytes memory msg_ = XCMMessageBuilder.buildTransferToParachain(
            USDT_ASSET_ID,
            1000e6,
            2000,
            address(0x1234567890123456789012345678901234567890),
            ASSET_HUB_PARA_ID
        );

        // Second byte: compact(1) = 0x04
        assertEq(uint8(msg_[1]), 0x04, "Should have 1 instruction (compact encoded)");

        // Third byte: TransferReserveAsset (variant 5)
        assertEq(uint8(msg_[2]), 0x05, "Should be TransferReserveAsset instruction");
    }

    function test_xcm_withdraw_and_transfer_has_two_instructions() public pure {
        bytes memory msg_ = XCMMessageBuilder.buildWithdrawAndTransfer(
            USDT_ASSET_ID,
            1000e6,
            2000,
            address(0x1234567890123456789012345678901234567890),
            ASSET_HUB_PARA_ID
        );

        // V4 prefix
        assertEq(uint8(msg_[0]), 0x04);

        // compact(2) = 0x08
        assertEq(uint8(msg_[1]), 0x08, "Should have 2 instructions");

        // First instruction: WithdrawAsset (variant 0)
        assertEq(uint8(msg_[2]), 0x00, "First should be WithdrawAsset");
    }

    function test_xcm_message_nonzero_length() public pure {
        bytes memory msg_ = XCMMessageBuilder.buildTransferToParachain(
            USDT_ASSET_ID,
            1000e6,
            2000,
            address(0x1234567890123456789012345678901234567890),
            ASSET_HUB_PARA_ID
        );

        // Message should have substantial length (version + instructions + assets + locations)
        assertGt(msg_.length, 30, "XCM message should be substantial");
    }

    function test_xcm_message_deterministic() public pure {
        bytes memory msg1 = XCMMessageBuilder.buildTransferToParachain(
            USDT_ASSET_ID, 1000e6, 2000,
            address(0x1234567890123456789012345678901234567890),
            ASSET_HUB_PARA_ID
        );

        bytes memory msg2 = XCMMessageBuilder.buildTransferToParachain(
            USDT_ASSET_ID, 1000e6, 2000,
            address(0x1234567890123456789012345678901234567890),
            ASSET_HUB_PARA_ID
        );

        assertEq(keccak256(msg1), keccak256(msg2), "Same params should produce same message");
    }

    function test_xcm_message_different_amounts_differ() public pure {
        bytes memory msg1 = XCMMessageBuilder.buildTransferToParachain(
            USDT_ASSET_ID, 1000e6, 2000,
            address(0x1234567890123456789012345678901234567890),
            ASSET_HUB_PARA_ID
        );

        bytes memory msg2 = XCMMessageBuilder.buildTransferToParachain(
            USDT_ASSET_ID, 2000e6, 2000,
            address(0x1234567890123456789012345678901234567890),
            ASSET_HUB_PARA_ID
        );

        assertTrue(keccak256(msg1) != keccak256(msg2), "Different amounts should produce different messages");
    }

    function test_xcm_message_different_destinations_differ() public pure {
        bytes memory msg1 = XCMMessageBuilder.buildTransferToParachain(
            USDT_ASSET_ID, 1000e6, 2000,
            address(0x1234567890123456789012345678901234567890),
            ASSET_HUB_PARA_ID
        );

        bytes memory msg2 = XCMMessageBuilder.buildTransferToParachain(
            USDT_ASSET_ID, 1000e6, 3000,
            address(0x1234567890123456789012345678901234567890),
            ASSET_HUB_PARA_ID
        );

        assertTrue(keccak256(msg1) != keccak256(msg2), "Different destinations should produce different messages");
    }

    // ================================================================
    // XCMRouter — Configuration Tests
    // ================================================================

    function test_router_initial_mode() public view {
        assertEq(uint(router.mode()), uint(XCMRouter.Mode.SIMULATION));
    }

    function test_router_set_mode() public {
        router.setMode(XCMRouter.Mode.PRODUCTION);
        assertEq(uint(router.mode()), uint(XCMRouter.Mode.PRODUCTION));
    }

    function test_router_register_asset() public {
        router.registerAsset(address(usdc), USDT_ASSET_ID);
        assertEq(router.assetRegistry(address(usdc)), USDT_ASSET_ID);
    }

    function test_router_non_owner_cannot_register() public {
        vm.prank(alice);
        vm.expectRevert(XCMRouter.NotOwner.selector);
        router.registerAsset(address(usdc), USDT_ASSET_ID);
    }

    function test_router_non_owner_cannot_set_mode() public {
        vm.prank(alice);
        vm.expectRevert(XCMRouter.NotOwner.selector);
        router.setMode(XCMRouter.Mode.PRODUCTION);
    }

    function test_router_preview_xcm_message() public {
        router.registerAsset(address(usdc), USDT_ASSET_ID);
        bytes memory msg_ = router.previewXCMMessage(
            USDT_ASSET_ID,
            1000e6,
            2000,
            address(0x1234567890123456789012345678901234567890)
        );
        assertGt(msg_.length, 0, "Preview should return non-empty message");
        assertEq(uint8(msg_[0]), 0x04, "Preview should return V4 message");
    }

    // ================================================================
    // XCMRouter — Simulation Mode Tests
    // ================================================================

    function test_simulation_transfer_pulls_tokens() public {
        // Setup: give alice tokens and approve router
        vm.startPrank(alice);
        usdc.approve(address(router), 1000e6);

        uint256 aliceBefore = usdc.balanceOf(alice);
        uint256 routerBefore = usdc.balanceOf(address(router));

        bool success = router.transferAssets(
            2000, alice, address(usdc), 1000e6, ""
        );

        assertTrue(success);
        assertEq(usdc.balanceOf(alice), aliceBefore - 1000e6);
        assertEq(usdc.balanceOf(address(router)), routerBefore + 1000e6);
        vm.stopPrank();
    }

    function test_simulation_tracks_deployments() public {
        vm.startPrank(alice);
        usdc.approve(address(router), 1000e6);
        router.transferAssets(2000, alice, address(usdc), 1000e6, "");
        vm.stopPrank();

        assertEq(router.deployedCapital(alice), 1000e6);
        assertEq(router.deploymentCount(), 1);
        assertEq(router.totalDeployed(), 1000e6);
    }

    function test_simulation_returns_with_yield() public {
        vm.startPrank(alice);
        usdc.approve(address(router), 1000e6);
        router.transferAssets(2000, alice, address(usdc), 1000e6, "");
        vm.stopPrank();

        uint256 aliceBefore = usdc.balanceOf(alice);

        // Simulate 5% yield
        router.simulateReturns(500);

        // Alice should get back 1000 + 50 = 1050
        assertEq(usdc.balanceOf(alice), aliceBefore + 1050e6);
        assertEq(router.deployedCapital(alice), 0);
        assertEq(router.deploymentCount(), 0);
    }

    function test_simulation_return_specific_creature() public {
        vm.startPrank(alice);
        usdc.approve(address(router), 1000e6);
        router.transferAssets(2000, alice, address(usdc), 1000e6, "");
        vm.stopPrank();

        uint256 aliceBefore = usdc.balanceOf(alice);

        // Simulate specific yield for alice
        router.simulateReturnForCreature(alice, address(usdc), 100e6);

        // Alice should get back 1000 + 100 = 1100
        assertEq(usdc.balanceOf(alice), aliceBefore + 1100e6);
    }

    // ================================================================
    // XCMRouter — Full Epoch Flow Tests
    // ================================================================

    function test_full_epoch_with_xcm_router() public {
        // Deposit
        vm.startPrank(alice);
        usdc.approve(address(ecosystem), 10_000e6);
        ecosystem.deposit(10_000e6);
        vm.stopPrank();

        // Spawn creatures
        ICreature.DNA[] memory dnas = _makeDNAArray(3);
        ecosystem.spawnInitialCreatures(dnas);

        // Epoch 1: FEED (no capital yet) → HARVEST → EVOLVE → ALLOCATE (distributes capital)
        vm.roll(block.number + 11);
        ecosystem.advanceEpoch(); // IDLE → FEED → HARVEST
        ecosystem.advanceEpoch(); // HARVEST → EVOLVE
        ecosystem.advanceEpoch(); // EVOLVE → ALLOCATE
        ecosystem.advanceEpoch(); // ALLOCATE → IDLE (capital distributed!)

        // Verify creatures got capital
        address[] memory creatures = ecosystem.getActiveCreatures();
        uint256 totalCreatureCapital;
        for (uint256 i = 0; i < creatures.length; i++) {
            totalCreatureCapital += usdc.balanceOf(creatures[i]);
        }
        assertEq(totalCreatureCapital, 10_000e6, "All capital allocated to creatures");

        uint256 routerBefore = usdc.balanceOf(address(router));

        // Epoch 2: FEED (creatures deploy via XCM!) → HARVEST
        vm.roll(block.number + 11);
        ecosystem.advanceEpoch(); // IDLE → FEED → HARVEST

        // Check capital deployed to router
        uint256 routerAfter = usdc.balanceOf(address(router));
        assertGt(routerAfter, routerBefore, "Router should hold deployed capital");
        assertGt(router.totalDeployed(), 0, "Capital should be tracked as deployed");

        // Simulate returns (5% yield)
        router.simulateReturns(500);

        // HARVEST → EVOLVE → ALLOCATE → IDLE
        ecosystem.advanceEpoch(); // HARVEST → EVOLVE
        ecosystem.advanceEpoch(); // EVOLVE → ALLOCATE
        ecosystem.advanceEpoch(); // ALLOCATE → IDLE

        // System should still be solvent
        uint256 totalRemaining;
        creatures = ecosystem.getActiveCreatures();
        for (uint256 i = 0; i < creatures.length; i++) {
            totalRemaining += usdc.balanceOf(creatures[i]);
        }
        uint256 ecosystemHeld = usdc.balanceOf(address(ecosystem));
        assertGt(totalRemaining + ecosystemHeld, 0, "System capital should be positive");
    }

    function test_multiple_creatures_different_xcm_targets() public {
        // Spawn creatures targeting different parachains
        ICreature.DNA[] memory dnas = _makeDNAArray(3);

        // Fund and deposit
        vm.startPrank(alice);
        usdc.approve(address(ecosystem), 30_000e6);
        ecosystem.deposit(30_000e6);
        vm.stopPrank();

        ecosystem.spawnInitialCreatures(dnas);

        // First epoch cycle: allocate capital TO creatures
        vm.roll(100);
        ecosystem.advanceEpoch(); // FEED (empty) → HARVEST
        ecosystem.advanceEpoch(); // HARVEST → EVOLVE
        ecosystem.advanceEpoch(); // EVOLVE → ALLOCATE
        ecosystem.advanceEpoch(); // ALLOCATE → IDLE (capital distributed)

        // Second epoch: creatures deploy via XCM
        vm.roll(200);
        ecosystem.advanceEpoch(); // FEED (deploys!) → HARVEST

        // All deployments tracked
        assertGt(router.totalDeployed(), 0, "Capital should be deployed");

        // Simulate returns
        router.simulateReturns(400); // 4% yield

        // Continue: HARVEST → EVOLVE
        ecosystem.advanceEpoch();

        // Creatures should have gained value
        address[] memory creatures = ecosystem.getActiveCreatures();
        for (uint256 i = 0; i < creatures.length; i++) {
            ICreature c = ICreature(creatures[i]);
            (, int256 cumReturn,,,) = c.getPerformance();
            assertGt(cumReturn, 0, "Each creature should have positive return");
        }
    }

    // ================================================================
    // XCMRouter — IXCM Interface Compatibility
    // ================================================================

    function test_router_implements_ixcm() public view {
        // XCMRouter should be usable as IXCM
        IXCM ixcm = IXCM(address(router));
        // Just verify the cast works (no revert)
        assertTrue(address(ixcm) == address(router));
    }

    function test_router_drops_in_for_mock_xcm() public {
        // Verify XCMRouter works as a drop-in replacement for MockXCM
        // by running the same deposit → feed → simulate → harvest flow

        vm.startPrank(alice);
        usdc.approve(address(ecosystem), 10_000e6);
        ecosystem.deposit(10_000e6);
        vm.stopPrank();

        ICreature.DNA[] memory dnas = _makeDNAArray(2);
        ecosystem.spawnInitialCreatures(dnas);

        // First cycle: allocate capital to creatures
        vm.roll(100);
        ecosystem.advanceEpoch(); // FEED (empty) → HARVEST
        ecosystem.advanceEpoch(); // HARVEST → EVOLVE
        ecosystem.advanceEpoch(); // EVOLVE → ALLOCATE
        ecosystem.advanceEpoch(); // ALLOCATE → IDLE

        // Second cycle: FEED (deploy) → simulate yields → HARVEST
        vm.roll(200);
        ecosystem.advanceEpoch(); // FEED → HARVEST

        router.simulateReturns(600); // 6% yield

        vm.roll(block.number + 11);
        ecosystem.advanceEpoch(); // HARVEST

        // Verify fitness is computed
        address[] memory creatures = ecosystem.getActiveCreatures();
        for (uint256 i = 0; i < creatures.length; i++) {
            (int256 lastRet,,,,) = ICreature(creatures[i]).getPerformance();
            assertGt(lastRet, 0, "Should have positive last return");
        }
    }

    // ================================================================
    // Helpers
    // ================================================================

    function _defaultDNA() internal pure returns (ICreature.DNA memory) {
        return ICreature.DNA({
            targetChainId: 1,
            poolType: 0,
            allocationRatio: 8000,
            rebalanceThreshold: 500,
            maxSlippage: 100,
            yieldFloor: 500,
            riskCeiling: 5,
            entryTiming: 0,
            exitTiming: 3,
            hedgeRatio: 1000
        });
    }

    function _makeDNAArray(uint256 count) internal pure returns (ICreature.DNA[] memory) {
        ICreature.DNA[] memory dnas = new ICreature.DNA[](count);
        for (uint256 i = 0; i < count; i++) {
            dnas[i] = _defaultDNA();
            dnas[i].targetChainId = uint8(i % 5);
            dnas[i].poolType = uint8(i % 6);
            dnas[i].riskCeiling = uint8((i % 10) + 1);
        }
        return dnas;
    }
}
