Web3 = require "web3"

detectWeb3 = () ->
  if typeof(web3) != 'undefined'
    console.log('Web3 injected browser: OK.')
    window.web3 = new Web3(window.web3.currentProvider)
  else
    console.log('Web3 injected browser: Fail. You should consider trying MetaMask.')
    # fallback - use your fallback strategy (local node / hosted node + in-dapp id mgmt / fail)
    window.web3 = new Web3(new Web3.providers.HttpProvider('http://localhost:8545'))
  return new Web3(web3.currentProvider)

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
