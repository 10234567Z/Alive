// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

import "forge-std/Test.sol";
import {Ecosystem} from "../src/Ecosystem.sol";
import {Creature} from "../src/Creature.sol";
import {CreatureFactory} from "../src/CreatureFactory.sol";
import {GenePool} from "../src/GenePool.sol";
import {ICreature} from "../src/interfaces/ICreature.sol";
import {MockStablecoin} from "./mocks/MockStablecoin.sol";
import {MockXCM} from "./mocks/MockXCM.sol";
import {MockEvolutionEngine} from "./mocks/MockEvolutionEngine.sol";

/// @title ALIVE Integration Test
/// @notice Tests the full lifecycle: deploy → deposit → spawn → feed → harvest → evolve → allocate
contract ALIVETest is Test {
    // ----------------------------------------------------------------
    // State
    // ----------------------------------------------------------------

    Ecosystem public ecosystem;
    CreatureFactory public factory;
    GenePool public genePool;
    MockStablecoin public usdc;
    MockXCM public xcm;
    MockEvolutionEngine public evoEngine;

    address public alice = makeAddr("alice");
    address public bob = makeAddr("bob");
    address public seeder = makeAddr("seeder");

    uint256 constant EPOCH_DURATION = 10; // blocks

    // ----------------------------------------------------------------
    // Setup
    // ----------------------------------------------------------------

    function setUp() public {
        // Deploy mocks
        usdc = new MockStablecoin();
        xcm = new MockXCM();
        evoEngine = new MockEvolutionEngine();

        // Deploy factory first (ecosystem address set later)
        factory = new CreatureFactory(
            address(usdc),
            address(xcm)
        );

        // Deploy Ecosystem pointing to factory
        ecosystem = new Ecosystem(
            address(usdc),
            address(factory),
            EPOCH_DURATION
        );

        // Wire factory → ecosystem
        factory.setEcosystem(address(ecosystem));

        // Deploy GenePool
        genePool = new GenePool(
            address(ecosystem),
            address(factory),
            address(evoEngine),
            3000, // survivalThreshold: top 30%
            2000, // deathThreshold: bottom 20%
            1000, // mutationRate: 10%
            50,   // maxPopulation
            seeder
        );

        // Wire up: set genePool on factory and ecosystem
        factory.setGenePool(address(genePool));
        ecosystem.setGenePool(address(genePool));
        ecosystem.setXCMRouter(address(xcm));

        // Fund users
        usdc.mint(alice, 100_000e6);
        usdc.mint(bob, 50_000e6);
    }

    // ----------------------------------------------------------------
    // Helpers
    // ----------------------------------------------------------------

    function _defaultDNA() internal pure returns (ICreature.DNA memory) {
        return ICreature.DNA({
            targetChainId: 1,     // parachain 1
            poolType: 0,          // AMM_LP
            allocationRatio: 8000, // 80%
            rebalanceThreshold: 500, // 5%
            maxSlippage: 100,     // 1%
            yieldFloor: 500,      // 5% annualized
            riskCeiling: 5,       // medium risk
            entryTiming: 0,       // immediate
            exitTiming: 3,        // 3 epochs
            hedgeRatio: 1000      // 10%
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

    // ----------------------------------------------------------------
    // Tests: Ecosystem Deposit / Withdraw
    // ----------------------------------------------------------------

    function test_deposit() public {
        uint256 depositAmount = 10_000e6;

        vm.startPrank(alice);
        usdc.approve(address(ecosystem), depositAmount);
        ecosystem.deposit(depositAmount);
        vm.stopPrank();

        assertEq(ecosystem.shares(alice), depositAmount);
        assertEq(ecosystem.totalShares(), depositAmount);
        assertEq(ecosystem.totalCapital(), depositAmount);
        assertEq(usdc.balanceOf(address(ecosystem)), depositAmount);
    }

    function test_deposit_multiple_users() public {
        vm.startPrank(alice);
        usdc.approve(address(ecosystem), 10_000e6);
        ecosystem.deposit(10_000e6);
        vm.stopPrank();

        vm.startPrank(bob);
        usdc.approve(address(ecosystem), 5_000e6);
        ecosystem.deposit(5_000e6);
        vm.stopPrank();

        assertEq(ecosystem.totalShares(), 15_000e6);
        assertEq(ecosystem.totalCapital(), 15_000e6);
        assertEq(ecosystem.shares(alice), 10_000e6);
        assertEq(ecosystem.shares(bob), 5_000e6);
    }

    function test_withdraw() public {
        vm.startPrank(alice);
        usdc.approve(address(ecosystem), 10_000e6);
        ecosystem.deposit(10_000e6);
        ecosystem.withdraw(5_000e6); // withdraw half shares
        vm.stopPrank();

        assertEq(ecosystem.shares(alice), 5_000e6);
        assertEq(ecosystem.totalCapital(), 5_000e6);
        assertEq(usdc.balanceOf(alice), 95_000e6); // started with 100k, deposited 10k, withdrew 5k
    }

    function test_withdraw_reverts_insufficient_shares() public {
        vm.startPrank(alice);
        usdc.approve(address(ecosystem), 1_000e6);
        ecosystem.deposit(1_000e6);

        vm.expectRevert("Ecosystem: insufficient shares");
        ecosystem.withdraw(2_000e6);
        vm.stopPrank();
    }

    function test_deposit_reverts_zero() public {
        vm.prank(alice);
        vm.expectRevert("Ecosystem: zero deposit");
        ecosystem.deposit(0);
    }

    // ----------------------------------------------------------------
    // Tests: Creature Lifecycle
    // ----------------------------------------------------------------

    function test_spawn_initial_creatures() public {
        ICreature.DNA[] memory dnas = _makeDNAArray(5);
        ecosystem.spawnInitialCreatures(dnas);

        assertEq(ecosystem.getCreatureCount(), 5);

        address[] memory creatures = ecosystem.getActiveCreatures();
        for (uint256 i = 0; i < creatures.length; i++) {
            assertTrue(ICreature(creatures[i]).isAlive());
            assertEq(ICreature(creatures[i]).generation(), 0);
        }
    }

    function test_spawn_reverts_if_already_spawned() public {
        ICreature.DNA[] memory dnas = _makeDNAArray(3);
        ecosystem.spawnInitialCreatures(dnas);

        vm.expectRevert("Ecosystem: already spawned");
        ecosystem.spawnInitialCreatures(dnas);
    }

    function test_creature_dna_is_correct() public {
        ICreature.DNA[] memory dnas = _makeDNAArray(1);
        ecosystem.spawnInitialCreatures(dnas);

        address creatureAddr = ecosystem.activeCreatures(0);
        ICreature.DNA memory retrievedDna = ICreature(creatureAddr).getDNA();

        assertEq(retrievedDna.targetChainId, dnas[0].targetChainId);
        assertEq(retrievedDna.poolType, dnas[0].poolType);
        assertEq(retrievedDna.allocationRatio, dnas[0].allocationRatio);
        assertEq(retrievedDna.hedgeRatio, dnas[0].hedgeRatio);
    }

    function test_creature_receive_capital() public {
        ICreature.DNA[] memory dnas = _makeDNAArray(2);
        ecosystem.spawnInitialCreatures(dnas);

        // Alice deposits
        vm.startPrank(alice);
        usdc.approve(address(ecosystem), 10_000e6);
        ecosystem.deposit(10_000e6);
        vm.stopPrank();

        // Advance epoch to trigger allocation
        vm.roll(block.number + EPOCH_DURATION + 1);
        ecosystem.advanceEpoch(); // IDLE → FEEDING (also feeds)

        // Move to HARVESTING → EVOLVING → ALLOCATING → IDLE
        ecosystem.advanceEpoch(); // HARVESTING → EVOLVING
        ecosystem.advanceEpoch(); // EVOLVING → ALLOCATING (allocates capital)
        ecosystem.advanceEpoch(); // ALLOCATING → IDLE

        // Check that creatures received capital
        address[] memory creatures = ecosystem.getActiveCreatures();
        uint256 totalAllocated = 0;
        for (uint256 i = 0; i < creatures.length; i++) {
            uint256 bal = usdc.balanceOf(creatures[i]);
            totalAllocated += bal;
            assertGt(bal, 0, "Each creature should have balance");
        }

        // All capital should be distributed (may have rounding dust in ecosystem)
        assertApproxEqAbs(totalAllocated, 10_000e6, creatures.length, "All capital should be allocated");
    }

    // ----------------------------------------------------------------
    // Tests: Creature Kill
    // ----------------------------------------------------------------

    function test_creature_kill() public {
        ICreature.DNA[] memory dnas = _makeDNAArray(1);
        ecosystem.spawnInitialCreatures(dnas);

        address creatureAddr = ecosystem.activeCreatures(0);

        // Give creature some capital
        usdc.mint(address(ecosystem), 1_000e6);
        vm.prank(address(ecosystem));
        usdc.approve(creatureAddr, 1_000e6);
        vm.prank(address(ecosystem));
        ICreature(creatureAddr).receiveCapital(1_000e6);

        // Kill it
        vm.prank(address(ecosystem));
        ICreature(creatureAddr).kill();

        assertFalse(ICreature(creatureAddr).isAlive());
        assertEq(usdc.balanceOf(creatureAddr), 0);
    }

    function test_creature_kill_reverts_non_ecosystem() public {
        ICreature.DNA[] memory dnas = _makeDNAArray(1);
        ecosystem.spawnInitialCreatures(dnas);

        address creatureAddr = ecosystem.activeCreatures(0);

        vm.prank(alice);
        vm.expectRevert("Creature: caller not ecosystem");
        ICreature(creatureAddr).kill();
    }

    // ----------------------------------------------------------------
    // Tests: Creature Feed
    // ----------------------------------------------------------------

    function test_creature_feed_calls_xcm() public {
        ICreature.DNA[] memory dnas = _makeDNAArray(1);
        ecosystem.spawnInitialCreatures(dnas);

        address creatureAddr = ecosystem.activeCreatures(0);

        // Give creature capital
        usdc.mint(address(ecosystem), 5_000e6);
        vm.startPrank(address(ecosystem));
        usdc.approve(creatureAddr, 5_000e6);
        ICreature(creatureAddr).receiveCapital(5_000e6);

        // Feed
        ICreature(creatureAddr).feed();
        vm.stopPrank();

        // XCM should have been called
        assertGt(xcm.callCount(), 0, "XCM should be called during feed");
    }

    // ----------------------------------------------------------------
    // Tests: Epoch Flow
    // ----------------------------------------------------------------

    function test_advance_epoch_reverts_too_early() public {
        vm.expectRevert("Ecosystem: epoch not elapsed");
        ecosystem.advanceEpoch();
    }

    function test_advance_epoch_changes_phase() public {
        ICreature.DNA[] memory dnas = _makeDNAArray(3);
        ecosystem.spawnInitialCreatures(dnas);

        vm.roll(block.number + EPOCH_DURATION + 1);

        // IDLE → FEEDING → HARVESTING (single call does both feed + transitions to HARVESTING)
        ecosystem.advanceEpoch();
        assertEq(uint256(ecosystem.phase()), uint256(Ecosystem.Phase.HARVESTING));

        // HARVESTING → EVOLVING
        ecosystem.advanceEpoch();
        assertEq(uint256(ecosystem.phase()), uint256(Ecosystem.Phase.EVOLVING));

        // EVOLVING → ALLOCATING
        ecosystem.advanceEpoch();
        assertEq(uint256(ecosystem.phase()), uint256(Ecosystem.Phase.ALLOCATING));

        // ALLOCATING → IDLE
        ecosystem.advanceEpoch();
        assertEq(uint256(ecosystem.phase()), uint256(Ecosystem.Phase.IDLE));
    }

    function test_full_epoch_cycle() public {
        // Setup: spawn creatures and deposit capital
        ICreature.DNA[] memory dnas = _makeDNAArray(5);
        ecosystem.spawnInitialCreatures(dnas);

        vm.startPrank(alice);
        usdc.approve(address(ecosystem), 50_000e6);
        ecosystem.deposit(50_000e6);
        vm.stopPrank();

        assertEq(ecosystem.currentEpoch(), 0);

        // Advance to first epoch
        vm.roll(block.number + EPOCH_DURATION + 1);
        ecosystem.advanceEpoch(); // feed phase → transitions to HARVEST
        assertEq(ecosystem.currentEpoch(), 1);

        ecosystem.advanceEpoch(); // harvest → EVOLVING
        ecosystem.advanceEpoch(); // evolve → ALLOCATING
        ecosystem.advanceEpoch(); // allocate → IDLE

        // Creatures should now have capital
        address[] memory creatures = ecosystem.getActiveCreatures();
        uint256 totalAllocated = 0;
        for (uint256 i = 0; i < creatures.length; i++) {
            totalAllocated += usdc.balanceOf(creatures[i]);
        }
        assertEq(totalAllocated, 50_000e6, "All capital should be allocated to creatures");
    }

    // ----------------------------------------------------------------
    // Tests: GenePool
    // ----------------------------------------------------------------

    function test_genepool_inject_seed() public {
        ICreature.DNA memory dna = _defaultDNA();

        vm.prank(seeder);
        address creature = genePool.injectSeed(dna, 0);

        assertTrue(ICreature(creature).isAlive());
        assertEq(ICreature(creature).generation(), 0);
    }

    function test_genepool_inject_seed_reverts_non_seeder() public {
        ICreature.DNA memory dna = _defaultDNA();

        vm.prank(alice);
        vm.expectRevert("GenePool: caller not seeder");
        genePool.injectSeed(dna, 0);
    }

    // ----------------------------------------------------------------
    // Tests: Factory
    // ----------------------------------------------------------------

    function test_factory_deploy() public {
        ICreature.DNA memory dna = _defaultDNA();

        vm.prank(address(ecosystem));
        address creature = factory.deploy(dna, 0, address(0), address(0), 0);

        assertTrue(creature != address(0));
        assertTrue(ICreature(creature).isAlive());
    }

    function test_factory_deploy_reverts_unauthorized() public {
        ICreature.DNA memory dna = _defaultDNA();

        vm.prank(alice);
        vm.expectRevert("CreatureFactory: unauthorized");
        factory.deploy(dna, 0, address(0), address(0), 0);
    }

    function test_factory_nonce_increments() public {
        ICreature.DNA memory dna = _defaultDNA();

        assertEq(factory.nonce(), 0);

        vm.prank(address(ecosystem));
        factory.deploy(dna, 0, address(0), address(0), 0);
        assertEq(factory.nonce(), 1);

        vm.prank(address(ecosystem));
        factory.deploy(dna, 0, address(0), address(0), 0);
        assertEq(factory.nonce(), 2);
    }

    // ----------------------------------------------------------------
    // Tests: Ecosystem View Functions
    // ----------------------------------------------------------------

    function test_ecosystem_state_view() public {
        ICreature.DNA[] memory dnas = _makeDNAArray(3);
        ecosystem.spawnInitialCreatures(dnas);

        vm.startPrank(alice);
        usdc.approve(address(ecosystem), 10_000e6);
        ecosystem.deposit(10_000e6);
        vm.stopPrank();

        (
            uint256 deposits,
            uint256 epoch,
            uint256 creatureCount,
            int256 yieldGenerated,
            Ecosystem.Phase currentPhase
        ) = ecosystem.getEcosystemState();

        assertEq(deposits, 10_000e6);
        assertEq(epoch, 0);
        assertEq(creatureCount, 3);
        assertEq(yieldGenerated, 0);
        assertEq(uint256(currentPhase), uint256(Ecosystem.Phase.IDLE));
    }

    function test_share_value() public {
        vm.startPrank(alice);
        usdc.approve(address(ecosystem), 10_000e6);
        ecosystem.deposit(10_000e6);
        vm.stopPrank();

        assertEq(ecosystem.shareValue(alice), 10_000e6);

        vm.startPrank(bob);
        usdc.approve(address(ecosystem), 10_000e6);
        ecosystem.deposit(10_000e6);
        vm.stopPrank();

        // Each user still has equal value
        assertEq(ecosystem.shareValue(alice), 10_000e6);
        assertEq(ecosystem.shareValue(bob), 10_000e6);
    }

    // ----------------------------------------------------------------
    // Tests: Encoded DNA
    // ----------------------------------------------------------------

    function test_creature_encoded_dna_roundtrip() public {
        ICreature.DNA[] memory dnas = _makeDNAArray(1);
        ecosystem.spawnInitialCreatures(dnas);

        address creatureAddr = ecosystem.activeCreatures(0);
        bytes memory encoded = ICreature(creatureAddr).getEncodedDNA();

        ICreature.DNA memory decoded = abi.decode(encoded, (ICreature.DNA));
        assertEq(decoded.targetChainId, dnas[0].targetChainId);
        assertEq(decoded.poolType, dnas[0].poolType);
        assertEq(decoded.allocationRatio, dnas[0].allocationRatio);
    }
}
