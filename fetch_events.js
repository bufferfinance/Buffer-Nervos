// node fetch_events.js

const { addressTranslator, getContract } = require("./utils");

// Pool
const pool = "0xaBbcae990aC9D3563831B1561E243e424A48Ea0b";

(async () => {
  const contract = await getContract("BufferBNBPool.json", pool);

  // Subscribe
  await contract.events.allEvents({
    fromBlock: "earliest",
  });

  // Fetch all events
  const events = await contract.getPastEvents("allEvents", {
    fromBlock: "earliest",
  });
  console.log(events);

  // Fetch specific events
  const provideEvents = await contract.getPastEvents("Provide", {
    fromBlock: "earliest",
  });
  console.log(provideEvents);
})();
