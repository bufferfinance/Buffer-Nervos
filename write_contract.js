const { writeContract } = require("./utils");
const { formatArgs } = require("./formatter");

const args = process.argv.slice(2);

(async () => {
  const output = await (args[3]
    ? writeContract(
        args[0],
        args[1],
        args[2],
        formatArgs(args[3], args[0], args[2])
      )
    : writeContract(args[0], args[1], args[2]));
  console.log(output);
})();
