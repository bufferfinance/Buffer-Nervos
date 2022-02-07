const { readContract, writeContract } = require("./utils");
const pp = "0x0bB0Cafd6cE6a54C82dF15F19F79f6BC7369116F";

const price = await readContract(
  "FakePriceProvider.json",
  pp,
  "latestRoundData"
);
const setPrice = writeContract(
  "FakePriceProvider.json",
  pp,
  "setPrice",
  2002100
);
