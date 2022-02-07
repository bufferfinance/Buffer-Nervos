const { getCompiledContractArtifact, addressTranslator } = require("./utils");

const formatArgs = (args, contract_name, funnction_name) => {
  let parsedArgs = args.slice(1, -1).split(",");
  parsedArgs = parsedArgs.map((arg) => arg.trim());

  const abi = getCompiledContractArtifact(contract_name).abi;

  const funcInputs = abi.filter((func) => func.name === funnction_name)[0]
    .inputs;
  const inputTypes = funcInputs.map((input) => input.type);

  const formattedArgs = inputTypes.map((input_type, index) => {
    if (input_type === "address") {
      const input = parsedArgs[index].slice(1, -1);
      return addressTranslator(input);
    } else if (input_type.includes("int")) {
      return parseInt(parsedArgs[index]);
    } else {
      return parsedArgs[index];
    }
  });
  return formattedArgs;
};

const formatOutput = (output, contract_name, funnction_name) => {
  let formattedOutput;
  if (typeof output === "object") {
    formattedOutput = Object.keys(output).map((item) => {
      return output[item];
    });
  } else {
    formattedOutput = output;
  }
  return formattedOutput;
};
module.exports = { formatArgs, formatOutput };
