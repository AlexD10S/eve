pragma solidity ^0.4.24;

import "./enigma/IEnigma.sol";

contract Tally {
    uint256 private constant ONE = 1;

    address public enigmaAddress;

    event TalliedVotes(int _tally);

    constructor (address _enigmaAddress) public {
        enigmaAddress = _enigmaAddress;
    }

    // submits encrypted votes to Enigma contract
    // Enigma doesn't have a standard format for input args yet
    // so this is more like a dummy
    function submitEncryptedVotes(bytes32[] _votes) public {
        IEnigma enigma = IEnigma(enigmaAddress);
        bytes32[] memory preprocessors = new bytes32[](0);
        uint fee = 0;

        bytes memory args = rlpEncode(_votes);

        // send compute request to Enigma
        require(
            enigma.compute(
                address(this),
                "_tallyVotes(int[])",
                args,
                "_callback(int)",
                fee,
                preprocessors,
                block.number + 10
            ) == IEnigma.ReturnValue.Ok);
    }

    // Encodes a bytes32 array using RLP encoding
    // Wraps the array in another array (to fit Enigma format)
    // Format: [ bytes32[] ]
    function rlpEncode(bytes32[] _data) public pure returns (bytes) {
        // handle empty array special case
        if (_data.length == 0) {
            bytes memory empty = new bytes(2);
            bytes2 emptyBytes = 0xc1c0;
            assembly {
                mstore(add(empty, 32), emptyBytes)
            }
            return empty;
        }
        
        // payload refers to the un-prefixed bytes32[] RLP encoded data
        require(_data.length * 33 < 2 ** 64 - 1);
        uint64 payloadLen = uint64(_data.length * 33); // plus 1 prefix byte for each item
        uint8 payloadLenNumBytes;
        bytes8 payloadLenBytes8;
        (payloadLenNumBytes, payloadLenBytes8) = toMinBytes(payloadLen);

        // metaPayload refers to the un-prefixed outer array's RLP encoded data
        require(payloadLen + 1 + payloadLenNumBytes < 2 ** 64 - 1);
        uint64 metaPayloadLen = payloadLen + 1 + payloadLenNumBytes;
        uint8 metaPayloadLenNumBytes;
        bytes8 metaPayloadLenBytes8;
        (metaPayloadLenNumBytes, metaPayloadLenBytes8) = toMinBytes(metaPayloadLen);
        
        bytes memory result = new bytes(metaPayloadLen + 1 + metaPayloadLenNumBytes); // plus 1 prefix byte and length bytes
        assembly {
            let resultPtr := add(result, 32) // first 32 bytes is length
            let dataPtr := add(_data, 32)
            
            // store outer array's prefix bytes 0xf7 + metaPayloadLenNumBytes
            mstore8(resultPtr, add(0xf7, metaPayloadLenNumBytes))
            resultPtr := add(resultPtr, 1)

            // store metaPayload length in fewest bits
            mstore(resultPtr, metaPayloadLenBytes8)
            resultPtr := add(resultPtr, metaPayloadLenNumBytes)

            // store bytes32[] prefix byte 0xf7 + payloadLenNumBytes
            mstore8(resultPtr, add(0xf7, payloadLenNumBytes))
            resultPtr := add(resultPtr, 1)

            // store payload length in fewest bits
            mstore(resultPtr, payloadLenBytes8)
            resultPtr := add(resultPtr, payloadLenNumBytes)

            // store items
            let prefix := 0xa0 // 0x80 + 0x20(32)
            for
                { let end := add(resultPtr, payloadLen) }
                lt(resultPtr, end)
                { 
                    resultPtr := add(resultPtr, 32)
                    dataPtr := add(dataPtr, 32)
                }
            {
                mstore8(resultPtr, prefix)
                resultPtr := add(resultPtr, 1)
                mstore(resultPtr, mload(dataPtr))
            }
        }
        return result;
    }

    /**
        Compute the largest integer smaller than or equal to the binary logarithm of the input.
        Source: https://github.com/bancorprotocol/contracts/blob/master/solidity/contracts/converter/BancorFormula.sol
    */
    function floorLog2(uint256 _n) internal pure returns (uint8) {
        uint8 res = 0;

        if (_n < 256) {
            // At most 8 iterations
            while (_n > 1) {
                _n >>= 1;
                res += 1;
            }
        }
        else {
            // Exactly 8 iterations
            for (uint8 s = 128; s > 0; s >>= 1) {
                if (_n >= (ONE << s)) {
                    _n >>= s;
                    res |= s;
                }
            }
        }

        return res;
    }

    // Converts a 64-bit uint to bytes8 and calculates how many bytes it takes up
    // returns (numBytes, nInBytes8)
    function toMinBytes(uint64 _n) internal pure returns (uint8, bytes8) {
        uint8 log2N = floorLog2(_n);
        // numBytes = ceil(floorLog2(_n) + 1 / 8)
        uint8 numBytes = (log2N + 1) / 8;
        numBytes += (log2N + 1) % 8 == 0 ? 0 : 1;
        bytes8 nInBytes8 = bytes8(_n) << (8 * (8 - numBytes));
        return (numBytes, nInBytes8);
    }

    // broadcasts the result of the tally
    // called by Enigma contract
    function _callback(int _tally) public {
        require(msg.sender == enigmaAddress);
        emit TalliedVotes(_tally);
    }

    // code for tallying the votes
    // called by Enigma worker
    function _tallyVotes(int[] _votes) public pure returns(int _tally) {
        assembly {
           let len := mul(mload(_votes), 32)
           let data := add(_votes, 32)

           for
               { let end := add(data, len) }
               lt(data, end)
               { data := add(data, 32) }
           {
               _tally := add(_tally, mload(data))
           }
        }
    }
}