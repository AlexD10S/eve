VOTING_ADDRESS = "0xc952b2291e5d913db0a91367cb643d12802e4ff0"
vote = "1"

engUtils = require "../../utils/enigma-utils"

Voting = artifacts.require "Voting"

config = require "./config.js"

derivedKey = engUtils.getDerivedKey(config.enclavePubKey, config.clientPrivKey)

module.exports = (callback) ->
    # encrypt vote
    encryptedVote = engUtils.encryptMessage(derivedKey, vote)
    console.log "Your unprefixed encrypted vote is #{encryptedVote}"

    # add prefix padding
    prefix = "0x"
    for i in [encryptedVote.length..63]
        prefix += "0"
    encryptedVote = prefix + encryptedVote
    console.log "Your encrypted vote is #{encryptedVote}"

    # audit submitted vote
    votingContract = await Voting.deployed()
    voteID = await votingContract.vote.call(encryptedVote)
    await votingContract.vote(encryptedVote)
    submittedVote = await votingContract.votes.call(voteID)
    console.log "Your submitted vote is #{submittedVote}, which is#{if submittedVote == encryptedVote then "" else "not"} equal to your original vote"
