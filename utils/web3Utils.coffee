Web3 = require "web3"
import { Connect } from 'uport-connect'

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

exports.detectWeb3 = detectWeb3
exports.getContractAddress = getContractAddress
exports.instantiateContract = instantiateContract
