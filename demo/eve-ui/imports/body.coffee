import "./body.html"
import { ReactiveVar } from 'meteor/reactive-var'

Web3Tools = require "./utils/web3Tools"
Voting = require './voting'

Web3 = require "web3"
web3 = window.web3

web3 = Web3Tools.detectWeb3(web3)


# initialise contracts
votingContractJSON = require "./abi/Voting.json"
votingContract = Web3Tools.instantiateContract(web3, votingContractJSON)
engContractJSON = require "./abi/Enigma.json"
engContract = Web3Tools.instantiateContract(web3, engContractJSON)

tally = new ReactiveVar(0)
vote = new ReactiveVar("")
numVotes = new ReactiveVar(0)
hasVoted = new ReactiveVar(false)
userAddress = new ReactiveVar("")


getCurrentTally = (getEnigmaEvents, getVoteTally) ->
  votes = await Voting.fetchVotes(getEnigmaEvents, fromBlock: 0)
  numVotes.set(votes.length)

  currentTally = await getVoteTally().call()
  tally.set(currentTally)


# Update value of hasVoted variable using given contract method and account
updateHasVoted = (getHasVoted, account) ->
  voted = await getHasVoted(account).call()
  hasVoted.set(voted)


$("document").ready(
    () ->
        web3.eth.defaultAccount = (await web3.eth.getAccounts())[0]
        userAddress.set(web3.eth.defaultAccount)

        # FIXME i would love to pass these global variables as params to the functions instead...
        votingContract = await votingContract
        engContract = await engContract

        updateHasVoted(votingContract.methods.hasVoted.bind(votingContract), web3.eth.defaultAccount)
        getCurrentTally(engContract.getPastEvents.bind(engContract), votingContract.methods.tally.bind(votingContract))
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
                [contractTally, nbVotes] = await Voting.tallyVotes(engContract.getPastEvents.bind(engContract), votingContract, web3.eth.defaultAccount)
                numVotes.set(nbVotes)
                tally.set(contractTally)
            when "Vote"
                voteOption = if $("#vote_option")[0].checked then "1" else "0"
                submittedVote = await Voting.submitVote(voteOption, votingContract, web3.eth.defaultAccount)
                updateHasVoted(votingContract.methods.hasVoted.bind(votingContract), web3.eth.defaultAccount)
                vote.set(submittedVote)
            when "Get current tally"
                await getCurrentTally(engContract.getPastEvents.bind(engContract), votingContract.methods.tally.bind(votingContract))

})
