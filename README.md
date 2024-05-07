## Food Chain System Smart Contract Overview

The "food_chain_system" module is a smart contract written in the Move programming language, designed to facilitate a decentralized food chain system. It introduces functionalities for managing products, consumers, complaints, and dispute resolutions within the food supply chain. Below is a detailed documentation of its components, purpose, features, setup, and interaction.

## Purpose:
The primary purpose of the "food_chain_system" module is to establish a transparent and efficient food supply chain system on a decentralized platform. It aims to ensure trust, fairness, and accountability among suppliers and consumers by providing mechanisms for product listing, ordering, complaints filing, and dispute resolution.

## Features:
1. **Product Management:** Suppliers can create new products for sale, specifying attributes such as description, quality, price, and duration. Consumers can view and order available products.
2. **Consumer Management:** Suppliers can add consumers with specific requirements for products, enabling targeted marketing and personalized offerings.
3. **Order Handling:** Consumers can place orders for products, and suppliers can choose consumers to fulfill orders and process payments.
4. **Complaints Handling:** Consumers can file complaints against suppliers for issues such as product quality or non-delivery within the specified deadline.
5. **Dispute Resolution:** An admin or arbitrator can resolve disputes between consumers and suppliers, ensuring fair outcomes and appropriate actions.

## Interaction:
After setting up the environment and deploying the smart contract, users can interact with it through various CLI commands. These commands include creating new products, adding consumers, placing orders, filing complaints, and resolving disputes. Each interaction follows a specific protocol, involving parameters such as product IDs, descriptions, quantities, and timestamps.

Overall, the "food_chain_system" smart contract module provides a robust framework for establishing and managing a decentralized food supply chain system. It promotes transparency, fairness, and accountability while ensuring the smooth flow of products from suppliers to consumers.
## Setup

### Prerequisites
Before we proceed, we should install a couple of things. Also, if you are using a Windows machine, it's recommended to use WSL2.

On Ubuntu/Debian/WSL2(Ubuntu):
```
sudo apt update
sudo apt install curl git-all cmake gcc libssl-dev pkg-config libclang-dev libpq-dev build-essential -y
```
On MacOs:
```
brew install curl cmake git libpq
```
If you don't have `brew` installed, run this:
```
/bin/bash -c "$(curl -fsSL https://raw.githubusercontent.com/Homebrew/install/HEAD/install.sh)"
```

Next, we need rust and cargo:
```
curl --proto '=https' --tlsv1.2 -sSf https://sh.rustup.rs | sh
```
if you get an error like this:
```
error: could not amend shell profile: '/home/codespace/.config/fish/conf.d/rustup.fish': could not write rcfile file: '/home/codespace/.config/fish/conf.d/rustup.fish': No such file or directory (os error 2)
```
run these commands and re-run the rustup script:
```
mkdir -p /home/codespace/.config/fish/conf.d
touch /home/codespace/.config/fish/conf.d/rustup.fish
```

### Install Sui
If you are using Github codespaces, it's recommended to use pre-built binaries rather than building them from source.

To download pre-built binaries, you should run `download-sui-binaries.sh` in the terminal. 
This scripts takes three parameters (in this particular order) - `version`, `environment` and `os`:
- sui version, for example `1.15.0`. You can lookup a more up-to-date version available here [SUI Github releases](https://github.com/MystenLabs/sui/releases).
- `environment` - that's the environment that you are targeting, in our case it's `testnet`. Other available options are: `devnet` and `mainnet`.
- `os` - name of the os. If you are using Github codespaces, put `ubuntu-x86_64`. Other available options are: `macos-arm64`, `macos-x86_64`, `ubuntu-x86_64`, `windows-x86_64` (not for WSL).

To donwload SUI binaries for codespace, run this command:
```
./download-sui-binaries.sh "v1.21.1" "testnet" "ubuntu-x86_64"
```
and restart your terminal window.

If you prefer to build the binaries from source, run this command in your terminal:
```
cargo install --locked --git https://github.com/MystenLabs/sui.git --branch testnet sui
```

### Install dev tools (not required, might take a while when installin in codespaces)
```
cargo install --git https://github.com/move-language/move move-analyzer --branch sui-move --features "address32"

```

### Run a local network
To run a local network with a pre-built binary (recommended way), run this command:
```
RUST_LOG="off,sui_node=info" sui-test-validator
```

Optionally, you can run it from sources.
```
git clone --branch testnet https://github.com/MystenLabs/sui.git

cd sui

RUST_LOG="off,sui_node=info" cargo run --bin sui-test-validator
```

### Install SUI Wallet (optionally)
```
https://chrome.google.com/webstore/detail/sui-wallet/opcgpfmipidbgpenhmajoajpbobppdil?hl=en-GB
```

### Configure connectivity to a local node
Once the local node is running (using `sui-test-validator`), you should the url of a local node - `http://127.0.0.1:9000` (or similar).
Also, another url in the output is the url of a local faucet - `http://127.0.0.1:9123`.

Next, we need to configure a local node. To initiate the configuration process, run this command in the terminal:
```
sui client active-address
```
The prompt should tell you that there is no configuration found:
```
Config file ["/home/codespace/.sui/sui_config/client.yaml"] doesn't exist, do you want to connect to a Sui Full node server [y/N]?
```
Type `y` and in the following prompts provide a full node url `http://127.0.0.1:9000` and a name for the config, for example, `localnet`.

On the last prompt you will be asked which key scheme to use, just pick the first one (`0` for `ed25519`).

After this, you should see the ouput with the wallet address and a mnemonic phrase to recover this wallet. You can save so later you can import this wallet into SUI Wallet.

Additionally, you can create more addresses and to do so, follow the next section - `Create addresses`.

### Testnet configuration

For the sake of this tutorial, let's add a testnet node:
```
sui client new-env --rpc https://fullnode.testnet.sui.io:443 --alias testnet
```
and switch to `testnet`:
```
sui client switch --env testnet
```

### Create addresses
For this tutorial we need two separate addresses. To create an address run this command in the terminal:
```
sui client new-address ed25519
```
where:
- `ed25519` is the key scheme (other available options are: `ed25519`, `secp256k1`, `secp256r1`)

And the output should be similar to this:
```
╭─────────────────────────────────────────────────────────────────────────────────────────────────╮
│ Created new keypair and saved it to keystore.                                                   │
├────────────────┬────────────────────────────────────────────────────────────────────────────────┤
│ address        │ 0x05db1e318f1e4bc19eb3f2fa407b3ebe1e7c3cd8147665aacf2595201f731519             │
│ keyScheme      │ ed25519                                                                        │
│ recoveryPhrase │ lava perfect chef million beef mean drama guide achieve garden umbrella second │
╰────────────────┴────────────────────────────────────────────────────────────────────────────────╯
```
Use `recoveryPhrase` words to import the address to the wallet app.


### Get localnet SUI tokens
```
curl --location --request POST 'http://127.0.0.1:9123/gas' --header 'Content-Type: application/json' \
--data-raw '{
    "FixedAmountRequest": {
        "recipient": "<ADDRESS>"
    }
}'
```
`<ADDRESS>` - replace this by the output of this command that returns the active address:
```
sui client active-address
```

You can switch to another address by running this command:
```
sui client switch --address <ADDRESS>
```
abd run the HTTP request to mint some SUI tokens to this account as well.

Also, you can top up the balance via the wallet app. To do that, you need to import an account to the wallet.

### Get testnet SUI tokens
After you switched to `testnet`, run this command to get 1 testnet SUI:
```
sui client faucet
```
it will use the the current active address and the current active network.

## Build and publish a smart contract

### Build package
To build tha package, you should run this command:
```
sui move build
```

If the package is built successfully, the next step is to publish the package:
### Publish package
```
sui client publish --gas-budget 100000000 --json
```
Here we do not specify the path to the package dir so it will use the current dir - `.`

After the contract is published we need to extract some object ids from the output. Here is the list of env variable that we source in the current shell and their values:
- `PACKAGE_ID` - the id of the published package. The json path to it is `.objectChanges[].packageId`
- `ORIGINAL_UPGRADE_CAP_ID` - the upgrade cap id that we might need if we find ourselves in the situation when we need to upgrade the contract. Path: `.objectChanges[].objectId` where `.objectChanges[].objectType` is  `0x2::package::UpgradeCap`
- `SUI_FEE_COIN_ID` the id of the SUI coin that we are going to use to pay the fee for the pool creation. Take any from the output of this command: `sui client gas --json`
- `ACCOUNT_ID1` - currently active address, assign the output of this command: `sui client active-address`. Repeat the same for the secondary account and assign the output to `ACCOUNT_ID1`
- `CLOCK_OBJECT_ID` - the id of the `Clock` object, default to `0x6`
- `BASE_COIN_TYPE` - the type of the SUI coin, default to `0x2::sui::SUI`
- `QUOTE_COIN_TYPE` - the type of the quote coin that we deployed for the sake of this tutorial. The coin is `WBTC` in the `wbtc` module in the `$PACKAGE_ID` package. So the value will look like this: `<PACKAGE_ID>::wbtc::WBTC`
- `WBTC_TREASURY_CAP_ID` it's the treasury cap id that is needed for token mint operations. In the publish output you should look for the object with `objectType` `0x2::coin::TreasuryCap<$PACKAGE_ID::wbtc::WBTC>` (replace `$PACKAGE_ID` with the actual package id) and this object also has `objectId` - that's the value that we are looking for.
