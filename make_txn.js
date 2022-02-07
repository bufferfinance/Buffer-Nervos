// node make_txn.js

const { transfer, addressTranslator } = require("./utils");
const toAddress = addressTranslator(
  "0xFbEA9559AE33214a080c03c68EcF1D3AF0f58A7D"
);
transfer(toAddress, 5608573060);
