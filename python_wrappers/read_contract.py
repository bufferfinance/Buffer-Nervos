import subprocess


def format_output(output):
    if 'object' in output:
        return output.replace("] object", "").replace('[', "").replace(" ", "").replace("'", "").split(',')
    else:
        return output.split(" ")[0]


def read(contract_address, contract_abi, function_name, *args):

    arguments = [
        contract_abi,
        contract_address,
        function_name,
        str(list(args)) if args else '[]'
    ]
    result = subprocess.run(['node', 'read_contract.js', *arguments],
                            stdout=subprocess.PIPE).stdout.decode('utf-8')
    print(f"{function_name} ==> {result}")
    return format_output(result)


# Example 1
contract_address = '0x0bB0Cafd6cE6a54C82dF15F19F79f6BC7369116F'
contract_abi = "FakePriceProvider.json"
function_name = "latestRoundData"

result = read(contract_address, contract_abi, function_name)
print(result)

# Example 2
contract_address = '0x075Dbc0e36eAbcAC7e9eBa9d3e261370F32434cA'
contract_abi = "BufferBNBPool.json"
function_name = "shareOf"
args = "0x08f8036A199f59163B0d02E8a53a05a215FfD716"

result = read(contract_address, contract_abi, function_name, args, 1)
print(result)
