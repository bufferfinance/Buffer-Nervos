const { existsSync } = require("fs");
const Web3 = require("web3");
const {
  PolyjuiceHttpProvider,
  PolyjuiceAccounts,
} = require("@polyjuice-provider/web3");

const DEPLOYER_PRIVATE_KEY =
  ""; // Replace this with your Ethereum private key with funds on Layer 2.

const polyjuiceConfig = {
  web3Url: "https://godwoken-testnet-web3-rpc.ckbapp.dev",
};

const provider = new PolyjuiceHttpProvider(
  polyjuiceConfig.web3Url,
  polyjuiceConfig
);
const getBytecodeFromArtifact = (contractArtifact) => {
  return contractArtifact.bytecode || contractArtifact.data?.bytecode?.object;
};

let web3, deployerAccount;

const getCompiledContractArtifact = (contractName) => {
  if (!contractName) {
    throw new Error(
      `No compiled contract specified to deploy. Please put it in "src/examples/2-deploy-contract/build/contracts" directory and provide its name as an argument to this program, eg.: "node index.js SimpleStorage.json"`
    );
  }
  let compiledContractArtifact = null;
  const filenames = [`./build/contracts/${contractName}`, `./${contractName}`];
  for (const filename of filenames) {
    if (existsSync(filename)) {
      // console.log(`Found file: ${filename}`);
      compiledContractArtifact = require(filename);
      break;
    } else console.log(`Checking for file: ${filename}`);
  }

  if (compiledContractArtifact === null)
    throw new Error(`Unable to find contract file: ${contractName}`);
  return compiledContractArtifact;
};

const getWeb3 = async () => {
  web3 = new Web3(provider);
  web3.eth.accounts = new PolyjuiceAccounts(polyjuiceConfig);
  deployerAccount = web3.eth.accounts.wallet.add(DEPLOYER_PRIVATE_KEY);
  web3.eth.Contract.setProvider(provider, web3.eth.accounts);
};

const deployContract = async (contractName, args) => {
  const compiledContractArtifact = getCompiledContractArtifact(contractName);
  provider.setMultiAbi([compiledContractArtifact.abi]);

  getWeb3();

  const balance = BigInt(await web3.eth.getBalance(deployerAccount.address));
  console.log(`${deployerAccount.address} wallet balance : ${balance}`);

  if (balance === 0n) {
    console.log(
      `Insufficient balance. Can't deploy contract. Please deposit funds to your Ethereum address: ${deployerAccount.address}`
    );
    return;
  }

  console.log(`Deploying ${contractName}...`);
  const deployTx = await new web3.eth.Contract(compiledContractArtifact.abi)
    .deploy({
      data: getBytecodeFromArtifact(compiledContractArtifact),
      arguments: args,
    })
    .send({
      from: deployerAccount.address,
    });

  // deployTx.on("transactionHash", (hash) =>
  //   console.log(`Transaction hash: ${hash}`)
  // );

  const contract = await deployTx;

  console.log(`Deployed contract address: ${contract.options.address}`);
  return contract.options.address;
};

const readContract = async (
  contractName,
  contractAddress,
  functionName,
  args
) => {
  const compiledContractArtifact = getCompiledContractArtifact(contractName);
  provider.setMultiAbi([compiledContractArtifact.abi]);

  getWeb3();

  const config = {
    from: deployerAccount.address,
  };
  const contract = new web3.eth.Contract(
    compiledContractArtifact.abi,
    contractAddress
  );

  const callResult = await contract.methods[functionName](...args).call(config);

  return callResult;
};

const writeContract = async (
  contractName,
  contractAddress,
  functionName,
  args,
  value
) => {
  const compiledContractArtifact = getCompiledContractArtifact(contractName);
  provider.setMultiAbi([compiledContractArtifact.abi]);

  getWeb3();

  const contract = new web3.eth.Contract(
    compiledContractArtifact.abi,
    contractAddress
  );
  const config = {
    from: deployerAccount.address,
    gas: 6000000,
    value: value || 0,
  };
  const tx = contract.methods[functionName](...args).send(config);

  // tx.on("transactionHash", (hash) =>
  //   console.log(`Write call transaction hash: ${hash}`)
  // );

  const receipt = await tx;
  return receipt;
};

const transfer = async (to, value) => {
  getWeb3();
  console.log({ deployerAccount });
  const config = {
    from: deployerAccount.address,
    gas: 6000000,
    value: value || 0,
  };
  const tx = deployerAccount.transfer(to, value);
  // .send(config);

  const receipt = await tx;
  return receipt;
};

const getContract = async (contractName, contractAddress) => {
  const compiledContractArtifact = getCompiledContractArtifact(contractName);
  provider.setMultiAbi([compiledContractArtifact.abi]);

  getWeb3();

  const contract = new web3.eth.Contract(
    compiledContractArtifact.abi,
    contractAddress
  );

  return contract;
};

const addressTranslator = (ethAddress) => {
  console.log({ ethAddress });
  var nervosGodwokenIntegration = require("nervos-godwoken-integration");
  const addressTranslator = new nervosGodwokenIntegration.AddressTranslator();
  const polyjuiceAddress =
    addressTranslator.ethAddressToGodwokenShortAddress(ethAddress);
  return polyjuiceAddress;
};

module.exports = {
  deployContract,
  addressTranslator,
  readContract,
  writeContract,
  getCompiledContractArtifact,
  getContract,
  transfer,
};
