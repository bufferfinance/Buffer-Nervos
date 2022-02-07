// node deploy_buffer_nervos_testnet_phase1.js

// Phase 1 : IBFR
const { deployContract } = require("./utils");
const ibfrContract = deployContract("IBFR.json", []);
