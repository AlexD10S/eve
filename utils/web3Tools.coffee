Web3 = require "web3"
import { Connect } from 'uport-connect'
EthCrypto = require 'eth-crypto'


detectWeb3 = () ->
  if typeof(web3) != 'undefined'
    console.log('Web3 injected browser: OK.')
    window.web3 = new Web3(window.web3.currentProvider)
  else
    console.log('Web3 injected browser: Fail. You should consider trying MetaMask.')
    # fallback - use your fallback strategy (uPort)
    uport = new Connect('EVE', {network: 'ropsten'})
    window.web3 = uport.getWeb3()
  return new Web3(window.web3.currentProvider)

getContractAddress = (web3, contractJSON) ->
  deployedAddress =
    web3.eth.net.getId()
    .then (networkId) ->
      contractJSON.networks[networkId].address
  return deployedAddress

instantiateContract = (web3, contractJSON) ->
  deployedAddress = getContractAddress(web3, contractJSON)
  return new web3.eth.Contract(contractJSON.abi, await deployedAddress)


###
Generate an Ethereum-like address from a public key

 @param publicKey
 @returns {*|string}
###
toAddress = (publicKey) ->
    EthCrypto.publicKey.toAddress (publicKey)


###
#Sign a message withs the specified private key
#
#  @param privateKey
#  @param message
#  @returns {string}
###
#sign = (privateKey, message) ->
#    EthCrypto.sign (privateKey, message)


exports.detectWeb3 = detectWeb3
exports.getContractAddress = getContractAddress
exports.instantiateContract = instantiateContract
exports.toAddress = toAddress
#exports.sign = sign
