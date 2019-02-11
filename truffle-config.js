/*
 * NB: since truffle-hdwallet-provider 0.0.5 you must wrap HDWallet providers in a
 * function when declaring them. Failure to do so will cause commands to hang. ex:
 * ```
 * mainnet: {
 *     provider: function() {
 *       return new HDWalletProvider(mnemonic, 'https://mainnet.infura.io/<infura-key>')
 *     },
 *     network_id: '1',
 *     gas: 4500000,
 *     gasPrice: 10000000000,
 *   },
 */
require('dotenv').config()
const HDWalletProvider = require("truffle-hdwallet-provider");

module.exports = {
  // See <http://truffleframework.com/docs/advanced/configuration>
  // to customize your Truffle configuration!
  networks: {
    development: {
      host: "localhost",
      port: 8545,
      gas: 4712388,
      network_id: "*" // match any network
    },
    rinkeby: {
      provider: function() {
        const mnemonic = require("./secret.json");
        return new HDWalletProvider(mnemonic, "https://rinkeby.infura.io/v3/9e5f0d08ad19483193cc86092b7512f2");
      },
      host: "localhost",
      port: 8545,
      gas: 6000000,
      gasPrice: 20 * Math.pow(10, 9),
      network_id: 4
    },
    ropsten: {
      provider: () => new HDWalletProvider(
          process.env.WHATISTHIS,
          process.env.ROPSTEN_URL),
      gas: 4712388,
      network_id: 3
    }
  },
  compilers: {
    solc: {
      version: "0.4.25",
    },
  },
  solc: {
    optimizer: {
      enabled: true,
      runs: 200
    }
  }
};
