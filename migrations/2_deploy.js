var Voting = artifacts.require("Voting");
var Enigma = artifacts.require("Enigma");

module.exports = async function(deployer, network, accounts) {
    deployer.then(async () => {
        // FIXME set second param (ENG address) to real value, here mock to allow deployment while unused
        enigma = await deployer.deploy(Enigma, accounts[0], accounts[0])
        await deployer.deploy(Voting, enigma.address);
    })
};
