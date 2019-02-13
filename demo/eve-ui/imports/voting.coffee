cryptoUtils = require "./utils/crypto.js"
rlp = require "rlp"
config = require "./config.js"

derivedKey = cryptoUtils.getDerivedKey(config.enclavePubKey, config.clientPrivKey)


removeLeadingZeroes = (x) ->
  while x.slice(0, 1) is "0"
    x = x.slice(1)
  return x


encryptVote = (inVote, encryptionKey) ->
  encryptedVote = cryptoUtils.encryptMessage(encryptionKey, inVote)
  console.log "Your unprefixed encrypted vote is #{encryptedVote}"

  # add prefix padding
  prefix = "0x"
  for i in [encryptedVote.length..63]
    prefix += "0"
  encryptedVote = prefix + encryptedVote
  console.log "Your encrypted vote is #{encryptedVote}"
  encryptedVote


submitVote = (_vote, votingContract, votingAccount) ->
  encryptedVote = encryptVote(_vote, derivedKey)

  # audit submitted vote
  voteID = await votingContract.methods.vote(encryptedVote).call()

  await votingContract.methods.vote(encryptedVote).send({ from: votingAccount })
  submittedVote = await votingContract.methods.votes(voteID).call()
  console.log "Your submitted vote is #{submittedVote}, which is#{if submittedVote is encryptedVote then "" else "not"} equal to your original vote"
  submittedVote


tallyVotes = (fetchEnigmaEvents, votingContract, web3Account) ->

  # submit votes to Enigma
  await votingContract.methods.submitVotesForTally().send({ from: web3Account })

  encryptedVotes = await fetchVotes(fetchEnigmaEvents, fromBlock: 0)

  console.log "Encrypted votes: " + encryptedVotes

  # decrypt votes
  decryptedVotes =
    cryptoUtils.decryptMessage(derivedKey, removeLeadingZeroes(encryptedVote.toString("hex"))) for encryptedVote in encryptedVotes

  console.log "Decrypted votes: #{decryptedVotes}"

  # tally votes
  calculatedTally = await votingContract.methods._tallyVotes(decryptedVotes).call()
  console.log "Tallied votes, result is #{calculatedTally[0]}"

  # update voting contract callback
  await votingContract.methods._callback(calculatedTally[0], calculatedTally[1]).send({ from: web3Account })

  # check tally
  contractTally = await votingContract.methods.tally().call()
  console.log "Tally submitted to the voting contract is #{contractTally}"

  return [contractTally, encryptedVotes.length]


fetchVotes = (fetchEnigmaEvents, fromBlock) ->

  events = await fetchEnigmaEvents("ComputeTask", fromBlock)
  eventsLength = events.length

  if eventsLength > 0
    input = events[eventsLength - 1].returnValues.callableArgs

    # decode data
    rawVotes = rlp.decode(input)
    votes = rawVotes[0]
    votes
  else []


exports.submitVote = submitVote
exports.tallyVotes = tallyVotes
exports.fetchVotes = fetchVotes
