// node deploy_buffer_nervos_testnet_phase3.js

// Phase 3 : BNB Options
const {
  deployContract,
  addressTranslator,
  readContract,
  writeContract,
} = require("./utils");

// Staking
const stakingAddress = addressTranslator(
  "0x842B620618bbdC0Ab5C1aA2928219428eBee5799"
);
console.log(addressTranslator("0xFbEA9559AE33214a080c03c68EcF1D3AF0f58A7D"));

// Pool
const pool = "0xc9493eaA42592afAE53061B95Aa7F4e092917069";
const poolAddress = addressTranslator(pool);

(async () => {
  // PriceProvider
  // const pp = await deployContract("FakePriceProvider.json", [2001000]);
  // const ppAddress = addressTranslator(pp);
  const ppAddress = "0x7b3cFC3deB199aE6DED192e8f4B0Ada85aD538c6";

  // Options
  const optionsConfigContract = await deployContract("BNBOptionConfig.json", [stakingAddress]);
  const feeCalculatorContract = await deployContract(
    "BNBFeeCalculator.json",
    []
  );
  const exercisorContract = await deployContract("BNBExercisor.json", []);

  // const optionsContract = await deployContract("BufferBNBOptions.json", [
  //   ppAddress,
  //   poolAddress,
  //   optionsConfigContract,
  //   feeCalculatorContract,
  //   exercisorContract,
  // ]);

  // // Setting pool permissions
  // const OPTION_ISSUER_ROLE = await readContract(
  //   "BufferBNBPool.json",
  //   pool,
  //   "OPTION_ISSUER_ROLE",
  //   []
  // );
  // const optionsAddress = addressTranslator(optionsContract);
  // await writeContract("BufferBNBPool.json", pool, "grantRole", [
  //   OPTION_ISSUER_ROLE,
  //   optionsAddress,
  // ]);

  // console.log({
  //   optionsConfigContract,
  //   feeCalculatorContract,
  //   exercisorContract,
  //   optionsContract,
  //   OPTION_ISSUER_ROLE,
  // });
})();
