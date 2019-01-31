import "./body.html"
import { ReactiveVar } from 'meteor/reactive-var'

Web3 = require "web3"
web3 = window.web3
Web3Utils = require "./utils/web3Utils"

web3 = Web3Utils.detectWeb3(web3)

# initialise contracts
votingContractJSON = require "./abi/Voting.json"
votingContract = Web3Utils.instantiateContract(web3, votingContractJSON)
engContractJSON = require "./abi/Enigma.json"
engContract = Web3Utils.instantiateContract(web3, engContractJSON)

tally = new ReactiveVar(0)
vote = new ReactiveVar("")
numVotes = new ReactiveVar(0)
hasVoted = new ReactiveVar(false)
userAddress = new ReactiveVar("")

engUtils = require "./utils/enigma-utils.js"
rlp = require "rlp"
config = require "./config.js"

derivedKey = engUtils.getDerivedKey(config.enclavePubKey, config.clientPrivKey)


removeLeadingZeroes = (x) ->
    while x.slice(0, 1) is "0"
        x = x.slice(1)
    return x


encryptVote = (inVote, encryptionKey) ->
  # encrypt vote
  encryptedVote = engUtils.encryptMessage(encryptionKey, inVote)
  console.log "Your unprefixed encrypted vote is #{encryptedVote}"

  # add prefix padding
  prefix = "0x"
  for i in [encryptedVote.length..63]
    prefix += "0"
  encryptedVote = prefix + encryptedVote
  console.log "Your encrypted vote is #{encryptedVote}"
  encryptedVote


submitVote = (_vote) ->
    encryptedVote = encryptVote(_vote, derivedKey)

    # audit submitted vote
    voteID = await votingContract.methods.vote(encryptedVote).call()
    votingAccount = web3.eth.defaultAccount

    await votingContract.methods.vote(encryptedVote).send({ from: votingAccount })
    submittedVote = await votingContract.methods.votes(voteID).call()
    console.log "Your submitted vote is #{submittedVote}, which is#{if submittedVote is encryptedVote then "" else "not"} equal to your original vote"
    submittedVote


tallyVotes = () ->
    # submit votes to Enigma
    await votingContract.methods.submitVotesForTally().send({ from: web3.eth.defaultAccount })

    events = await engContract.getPastEvents("ComputeTask",
        fromBlock: 0
    )
    input = events[events.length - 1].returnValues.callableArgs
    console.log "Fetched encrypted input: #{input}"

    # decode data
    rawVotes = rlp.decode(input)
    votes = rawVotes[0]
    console.log "Encrypted votes: " + votes
    numVotes.set(votes.length)

    # decrypt votes
    for i in [0..votes.length - 1]
        votes[i] = engUtils.decryptMessage(derivedKey, removeLeadingZeroes(votes[i].toString("hex")))

    console.log "Decrypted votes: #{votes}"

    # tally votes
    calculatedTally = await votingContract.methods._tallyVotes(votes).call()
    console.log "Tallied votes, result is #{calculatedTally[0]}"

    # update voting contract callback
    await votingContract.methods._callback(calculatedTally[0], calculatedTally[1]).send({ from: web3.eth.defaultAccount })

    # check tally
    tally.set(await votingContract.methods.tally().call())
    console.log "Tally submitted to the voting contract is #{tally.get()}"


getCurrentTally = () ->
    engContract.getPastEvents("ComputeTask",fromBlock: 0)
    .then (events) ->
        eventsLength = events.length
        if eventsLength > 0
            input = events[eventsLength - 1].returnValues.callableArgs

            # decode data
            rawVotes = rlp.decode(input)
            votes = rawVotes[0]
            numVotes.set(votes.length)

    votingContract.methods.tally().call()
    .then (t) ->
        tally.set(t)


updateHasVoted = (votingContract, account) ->
  votingContract.methods.hasVoted(account).call()
  .then (voted) ->
    hasVoted.set(voted)


$("document").ready(
    () ->
        web3.eth.defaultAccount = (await web3.eth.getAccounts())[0]
        userAddress.set(web3.eth.defaultAccount)

        # FIXME i would love to pass these global variables as params to the functions instead...
        votingContract = await votingContract
        engContract = await engContract

        updateHasVoted(votingContract, web3.eth.defaultAccount)
        getCurrentTally()
)


Template.body.helpers({
    tally: () -> tally.get()
    vote: () -> vote.get()
    num_votes: () -> numVotes.get()
    user_address: () -> userAddress.get()
    has_voted: () -> hasVoted.get()
})


Template.body.events({
    "click .button": (event) ->
        title = event.target.innerText
        switch title
            when "Tally votes & update tally (2 txs)"
                await tallyVotes()
            when "Vote"
                voteOption = if $("#vote_option")[0].checked then "1" else "0"
                await submitVote(voteOption)
            when "Get current tally"
                await getCurrentTally()

})
