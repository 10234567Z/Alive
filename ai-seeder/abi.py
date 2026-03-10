"""Minimal ABI fragments for the ALIVE contracts.

Only the functions that the AI Seeder actually calls are included.
"""

ECOSYSTEM_ABI = [
    {
        "name": "getEcosystemState",
        "type": "function",
        "stateMutability": "view",
        "inputs": [],
        "outputs": [
            {"name": "deposits", "type": "uint256"},
            {"name": "epoch", "type": "uint256"},
            {"name": "creatureCount", "type": "uint256"},
            {"name": "yieldGenerated", "type": "int256"},
            {"name": "currentPhase", "type": "uint8"},
        ],
    },
    {
        "name": "getActiveCreatures",
        "type": "function",
        "stateMutability": "view",
        "inputs": [],
        "outputs": [
            {"name": "", "type": "address[]"},
        ],
    },
    {
        "name": "currentEpoch",
        "type": "function",
        "stateMutability": "view",
        "inputs": [],
        "outputs": [
            {"name": "", "type": "uint256"},
        ],
    },
]

CREATURE_ABI = [
    {
        "name": "getDNA",
        "type": "function",
        "stateMutability": "view",
        "inputs": [],
        "outputs": [
            {
                "name": "",
                "type": "tuple",
                "components": [
                    {"name": "targetChainId", "type": "uint8"},
                    {"name": "poolType", "type": "uint8"},
                    {"name": "allocationRatio", "type": "uint16"},
                    {"name": "rebalanceThreshold", "type": "uint16"},
                    {"name": "maxSlippage", "type": "uint16"},
                    {"name": "yieldFloor", "type": "uint16"},
                    {"name": "riskCeiling", "type": "uint8"},
                    {"name": "entryTiming", "type": "uint8"},
                    {"name": "exitTiming", "type": "uint8"},
                    {"name": "hedgeRatio", "type": "uint16"},
                ],
            }
        ],
    },
    {
        "name": "getPerformance",
        "type": "function",
        "stateMutability": "view",
        "inputs": [],
        "outputs": [
            {"name": "lastReturn", "type": "int256"},
            {"name": "cumulativeReturn", "type": "int256"},
            {"name": "epochsSurvived", "type": "uint256"},
            {"name": "maxDrawdown", "type": "int256"},
            {"name": "isAlive", "type": "bool"},
        ],
    },
]

GENEPOOL_ABI = [
    {
        "name": "injectSeed",
        "type": "function",
        "stateMutability": "nonpayable",
        "inputs": [
            {
                "name": "dna",
                "type": "tuple",
                "components": [
                    {"name": "targetChainId", "type": "uint8"},
                    {"name": "poolType", "type": "uint8"},
                    {"name": "allocationRatio", "type": "uint16"},
                    {"name": "rebalanceThreshold", "type": "uint16"},
                    {"name": "maxSlippage", "type": "uint16"},
                    {"name": "yieldFloor", "type": "uint16"},
                    {"name": "riskCeiling", "type": "uint8"},
                    {"name": "entryTiming", "type": "uint8"},
                    {"name": "exitTiming", "type": "uint8"},
                    {"name": "hedgeRatio", "type": "uint16"},
                ],
            },
            {"name": "currentEpoch", "type": "uint256"},
        ],
        "outputs": [
            {"name": "creature", "type": "address"},
        ],
    },
]
