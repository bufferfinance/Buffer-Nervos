import subprocess


def write(contract_address, contract_abi, function_name, *args):

    arguments = [
        contract_abi,
        contract_address,
        function_name,
        str(list(args)) if args else '[]'
    ]
    print(arguments)
    result = subprocess.run(['node', 'write_contract.js', *arguments],
                            stdout=subprocess.PIPE).stdout.decode('utf-8')
    print(f"{function_name} ==> {result}")
    return result


# Example
contract_address = '0x0bB0Cafd6cE6a54C82dF15F19F79f6BC7369116F'
contract_abi = "FakePriceProvider.json"
function_name = "setPrice"
args = 2003100

result = write(contract_address, contract_abi, function_name, args)
print(result)
