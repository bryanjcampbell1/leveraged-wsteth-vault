# Levereged Vault for wstETH

Strategy that exposes a user to a leveraged position of wstETH while earn additional staking rewards. 

Manager can set an idealDebtToCollateral value in the stategy that represents the ratio Debt/Collateral multiplied by 1000.
We multiply by 100 to avoid rounding down in solidity division. 

## Installing dependencies

```shell
npm install -g npx
npm i
```

## Configure 

Our hardhat.config file makes use of an env var named INFURA_API_KEY
Create a .env file and add your infura key there. 

Alternatively, feel free to overwrite the url field in hardhat.config with your own rpc url string.

## Fork mainnet

```shell
npx hardhat node
```


## Compile and run tests

In another terminal window/tab run

```shell
npx hardhat test
```

This will both compile and run tests

## Future improvements
1) Create a strategy for Compound 
2) Create an upgradeable version of the contracts to be used along with a transparent proxy
3) Increase test coverage including scenarios where strategies and implementation contracts are updated
4) Write foundry tests to fuzz over different values of idealDebtToCollateral while deposit/withdraw
5) Add more quantitative tests by writing predictions in js
