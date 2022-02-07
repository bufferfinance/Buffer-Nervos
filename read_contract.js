const { readContract } = require("./utils");
const { formatArgs, formatOutput } = require("./formatter");

const args = process.argv.slice(2);

(async () => {
  const output = args[3]
    ? await readContract(
        args[0],
        args[1],
        args[2],
        formatArgs(args[3], args[0], args[2])
      )
    : await readContract(args[0], args[1], args[2]);
  const formattedOutput = formatOutput(output);
  console.log(formattedOutput, typeof formattedOutput);
})();
