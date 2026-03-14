// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

import {ICreature} from "./interfaces/ICreature.sol";
import {IEvolutionEngine} from "./interfaces/IEvolutionEngine.sol";
import {CreatureFactory} from "./CreatureFactory.sol";

/// @title GenePool
/// @notice Manages the evolutionary cycle: evaluates fitness, selects parents,
///         breeds offspring via crossover + mutation, and kills underperformers.
///
///         The genetic algorithm heavy-lifting (fitness scoring, crossover,
///         mutation) is delegated to the Evolution Engine running on PolkaVM
///         via the PVM precompile. This contract orchestrates the flow.
contract GenePool {
    // ----------------------------------------------------------------
    // State
    // ----------------------------------------------------------------

    address public ecosystem;
    CreatureFactory public factory;
    IEvolutionEngine public evolutionEngine;

    /// @notice Top N% survive and may become parents (basis points).
    uint256 public survivalThreshold; // e.g., 3000 = top 30%

    /// @notice Bottom N% are killed (basis points).
    uint256 public deathThreshold; // e.g., 2000 = bottom 20%

    /// @notice Probability of mutation per gene field (basis points).
    uint256 public mutationRate; // e.g., 1000 = 10%

    /// @notice Maximum allowed population.
    uint256 public maxPopulation;

    /// @notice Address authorized to inject seed Creatures (AI Seeder).
    address public seeder;

    /// @notice Per-creature fitness scores from the last evolution run.
    mapping(address => uint256) public lastFitnessScores;

    /// @notice Addresses of all creatures scored in the last evolution run.
    address[] internal _lastScoredCreatures;

    // ----------------------------------------------------------------
    // Events
    // ----------------------------------------------------------------

    event EvolutionRun(
        uint256 epoch,
        uint256 totalCreatures,
        uint256 killed,
        uint256 bred
    );
    event CreatureBred(
        address indexed offspring,
        address indexed parent1,
        address indexed parent2,
        uint256 generation
    );
    event CreatureKilled(address indexed creature, uint256 fitnessScore);
    event SeedInjected(address indexed creature);

    // ----------------------------------------------------------------
    // Modifiers
    // ----------------------------------------------------------------

    modifier onlyEcosystem() {
        require(msg.sender == ecosystem, "GenePool: caller not ecosystem");
        _;
    }

    modifier onlySeeder() {
        require(msg.sender == seeder, "GenePool: caller not seeder");
        _;
    }

    // ----------------------------------------------------------------
    // Constructor
    // ----------------------------------------------------------------

    constructor(
        address _ecosystem,
        address _factory,
        address _evolutionEngine,
        uint256 _survivalThreshold,
        uint256 _deathThreshold,
        uint256 _mutationRate,
        uint256 _maxPopulation,
        address _seeder
    ) {
        require(_survivalThreshold + _deathThreshold <= 10000, "GenePool: thresholds exceed 100%");
        require(_mutationRate <= 10000, "GenePool: mutationRate exceeds 100%");

        ecosystem = _ecosystem;
        factory = CreatureFactory(_factory);
        evolutionEngine = IEvolutionEngine(_evolutionEngine);
        survivalThreshold = _survivalThreshold;
        deathThreshold = _deathThreshold;
        mutationRate = _mutationRate;
        maxPopulation = _maxPopulation;
        seeder = _seeder;
    }

    // ----------------------------------------------------------------
    // Core: Evolution
    // ----------------------------------------------------------------

    /// @notice Run a full evolution cycle on the given set of Creatures.
    ///         Called by Ecosystem at each epoch transition.
    /// @param creatures The current active Creature addresses.
    /// @param currentEpoch The epoch number (used for offspring birthEpoch).
    /// @return newPopulation The updated list of active Creature addresses after
    ///         deaths and births.
    function runEvolution(
        address[] calldata creatures,
        uint256 currentEpoch
    ) external onlyEcosystem returns (address[] memory newPopulation) {
        uint256 len = creatures.length;
        if (len == 0) return creatures;

        // 1. Collect performance data from all living Creatures
        IEvolutionEngine.PerformanceRecord[] memory records =
            new IEvolutionEngine.PerformanceRecord[](len);

        for (uint256 i = 0; i < len; i++) {
            (
                int256 lr,
                int256 cr,
                uint256 es,
                int256 md,
                /* balance */
            ) = ICreature(creatures[i]).getPerformance();

            records[i] = IEvolutionEngine.PerformanceRecord({
                creatureAddr: creatures[i],
                lastReturn: lr,
                cumulativeReturn: cr,
                epochsSurvived: es,
                maxDrawdown: md
            });
        }

        // 2. Call PVM Evolution Engine for fitness scoring
        IEvolutionEngine.FitnessResult[] memory results =
            evolutionEngine.evaluateFitness(records);

        // 2b. Store fitness scores for Ecosystem to read
        //     Clear previous scores first
        for (uint256 i = 0; i < _lastScoredCreatures.length; i++) {
            delete lastFitnessScores[_lastScoredCreatures[i]];
        }
        delete _lastScoredCreatures;

        for (uint256 i = 0; i < results.length; i++) {
            lastFitnessScores[results[i].creatureAddr] = results[i].fitnessScore;
            _lastScoredCreatures.push(results[i].creatureAddr);
        }

        // results is sorted descending by fitnessScore
        // 3. Determine kill and parent thresholds
        uint256 parentCount = (len * survivalThreshold) / 10000;
        if (parentCount < 2) parentCount = 2; // need at least 2 parents
        if (parentCount > len) parentCount = len;

        uint256 killCount = (len * deathThreshold) / 10000;
        if (killCount >= len) killCount = len - 1; // never kill everyone

        // 4. Kill bottom performers
        // results[len-1] is worst, results[len-2] is second worst, etc.
        address[] memory killed = new address[](killCount);
        for (uint256 i = 0; i < killCount; i++) {
            uint256 killIdx = len - 1 - i;
            address victim = results[killIdx].creatureAddr;
            // Kill is called via the ecosystem so Creature's onlyEcosystem check passes
            // The ecosystem must proxy this call
            killed[i] = victim;
            emit CreatureKilled(victim, results[killIdx].fitnessScore);
        }

        // 5. Breed offspring from top performers
        //    Pair consecutive parents: (0,1), (2,3), ... 
        //    Each pair produces one offspring
        uint256 breedPairs = parentCount / 2;
        // Cap breeding so we don't exceed maxPopulation
        uint256 survivorCount = len - killCount;
        uint256 maxNewborn = maxPopulation > survivorCount ? maxPopulation - survivorCount : 0;
        if (breedPairs > maxNewborn) breedPairs = maxNewborn;

        address[] memory offspring = new address[](breedPairs);
        for (uint256 i = 0; i < breedPairs; i++) {
            address p1 = results[i * 2].creatureAddr;
            address p2 = results[i * 2 + 1].creatureAddr;
            uint256 parentGen1 = ICreature(p1).generation();
            uint256 parentGen2 = ICreature(p2).generation();
            uint256 childGen = (parentGen1 > parentGen2 ? parentGen1 : parentGen2) + 1;

            address child = _breed(p1, p2, childGen, currentEpoch);
            offspring[i] = child;

            emit CreatureBred(child, p1, p2, childGen);
        }

        // 6. Assemble new population: survivors + offspring
        newPopulation = new address[](survivorCount + breedPairs);
        uint256 idx = 0;

        // Add survivors (all creatures that are not in the killed list)
        for (uint256 i = 0; i < len; i++) {
            bool wasKilled = false;
            for (uint256 k = 0; k < killCount; k++) {
                if (results[len - 1 - k].creatureAddr == creatures[i]) {
                    wasKilled = true;
                    break;
                }
            }
            if (!wasKilled) {
                newPopulation[idx] = creatures[i];
                idx++;
            }
        }

        // Add offspring
        for (uint256 i = 0; i < breedPairs; i++) {
            newPopulation[idx] = offspring[i];
            idx++;
        }

        // 7. Return kill list for the Ecosystem to process the actual kill() calls
        // We store it transiently so Ecosystem can read it
        _pendingKills = killed;

        emit EvolutionRun(currentEpoch, len, killCount, breedPairs);
    }

    /// @notice Returns the list of Creatures that should be killed.
    ///         Ecosystem reads this after runEvolution and calls kill() on each.
    address[] internal _pendingKills;

    function getPendingKills() external view returns (address[] memory) {
        return _pendingKills;
    }

    // ----------------------------------------------------------------
    // Breeding
    // ----------------------------------------------------------------

    /// @dev Crossover + mutation through PVM, then deploy via Factory.
    function _breed(
        address p1,
        address p2,
        uint256 gen,
        uint256 epoch
    ) internal returns (address) {
        bytes memory dna1 = ICreature(p1).getEncodedDNA();
        bytes memory dna2 = ICreature(p2).getEncodedDNA();

        uint256 seed = uint256(keccak256(abi.encodePacked(
            block.prevrandao, block.timestamp, p1, p2, gen
        )));

        // Crossover via PVM
        bytes memory childDna = evolutionEngine.crossover(dna1, dna2, seed);

        // Mutation via PVM
        childDna = evolutionEngine.mutate(childDna, mutationRate, seed >> 128);

        // Decode and deploy
        ICreature.DNA memory decodedDna = abi.decode(childDna, (ICreature.DNA));
        address child = factory.deploy(decodedDna, gen, p1, p2, epoch);

        return child;
    }

    // ----------------------------------------------------------------
    // Seed Injection (AI Seeder)
    // ----------------------------------------------------------------

    /// @notice Inject a new seed Creature with externally generated DNA.
    ///         Only callable by the authorized seeder address.
    /// @param dna The DNA for the new Creature.
    /// @param currentEpoch The current epoch number.
    /// @return creature The address of the newly created Creature.
    function injectSeed(
        ICreature.DNA memory dna,
        uint256 currentEpoch
    ) external onlySeeder returns (address creature) {
        creature = factory.deploy(dna, 0, address(0), address(0), currentEpoch);
        // Register the creature in the Ecosystem's active population
        (bool ok, ) = ecosystem.call(
            abi.encodeWithSignature("registerCreature(address)", creature)
        );
        require(ok, "GenePool: failed to register creature");
        emit SeedInjected(creature);
    }

    // ----------------------------------------------------------------
    // Views
    // ----------------------------------------------------------------

    /// @notice Get the fitness score for a creature from the last evolution run.
    function getFitness(address creature) external view returns (uint256) {
        return lastFitnessScores[creature];
    }

    /// @notice Get all scored creature addresses from the last evolution run.
    function getLastScoredCreatures() external view returns (address[] memory) {
        return _lastScoredCreatures;
    }
}
