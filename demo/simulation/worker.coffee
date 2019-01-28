VOTING_ADDRESS = "0xc952b2291e5d913db0a91367cb643d12802e4ff0"
ENIGMA_ADDRESS = "0xffd5ce90e42e20c5d5259cf1fb15dd123cd5ccbe"

engUtils = require "../../utils/enigma-utils"
rlp = require "rlp"

Web3 = require("web3")
web3 = new Web3(new Web3.providers.HttpProvider("https://rinkeby.infura.io/v3/9e5f0d08ad19483193cc86092b7512f2"))

Voting = artifacts.require "Voting"
Enigma = artifacts.require "Enigma"

config = require "./config.js"
derivedKey = engUtils.getDerivedKey(config.enclavePubKey, config.clientPrivKey)

removeHeadingZeroes = (x) ->
    while x.slice(0, 1) == "0"
        x = x.slice(1)
    return x

module.exports = (callback) ->
    votingContract = await Voting.at(VOTING_ADDRESS)
    engContract = await Enigma.at(ENIGMA_ADDRESS)
    engContract = new web3.eth.Contract(engContract.abi, engContract.address)

    # submit votes to Enigma
    await votingContract.submitVotesForTally()

    events = await engContract.getPastEvents("ComputeTask",
        fromBlock: 0
    )
    input = events[events.length - 1].returnValues.callableArgs
    console.log "Fetched encrypted input: #{input}"

    # decode data
    rawVotes = rlp.decode(input)
    votes = rawVotes[0]
    console.log "Encrypted votes: " + votes

    # decrypt votes
    for i in [0..votes.length-1]
        votes[i] = engUtils.decryptMessage(derivedKey, removeHeadingZeroes(votes[i].toString("hex")))

    console.log "Decrypted votes: #{votes}"

    # tally votes
    calculatedTally = await votingContract._tallyVotes.call(votes)
    console.log "Tallied votes, result is #{calculatedTally}"

    # update voting contract callback
    await votingContract._callback(calculatedTally)

    # check tally
    tally = await votingContract.tally.call()
    console.log "Tally submitted to the voting contract is #{tally}"
