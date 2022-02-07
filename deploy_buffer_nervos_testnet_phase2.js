// node deploy_buffer_nervos_testnet_phase2.js

// Phase 2 : Staking and Pool
const { deployContract, addressTranslator } = require("./utils");

// IBFR
const ibfrAddress = addressTranslator(
  "0x344d7bBdc7a3E1195d2d28ac61BCa7f8A70CadCA"
);

(async () => {
  // Staking
  const stakingBNBContract = await deployContract("BufferStakingBNB.json", [
    ibfrAddress,
  ]);

  // Pool
  const bufferBNBPool = await deployContract("BufferBNBPool.json", []);
})();
