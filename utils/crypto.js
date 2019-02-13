const EC = require ('elliptic').ec;
const forge = require ('node-forge'); //TODO: account for browser

/**
 * This does ECDH key derivation from 2 EC secp256k1 keys.
 * It does so by multiplying the public points by the private point of the over key.
 * This results in a X and Y. it then replaces the Y with 0x02 if Y is even and 0x03 if it's odd.
 * Then it hashes the new Y together with the X using SHA256.
 * Multiplication: https://github.com/indutny/elliptic/blob/master/lib/elliptic/ec/key.js#L104
 * Replacing Y: https://source.that.world/source/libsecp256k1-rs/browse/master/src/ecdh.rs$25
 *
 * @param {string} enclavePublicKey
 * @param {string} clientPrivateKey
 * @returns {string}
 */
function getDerivedKey (enclavePublicKey, clientPrivateKey) {
    let ec = new EC ('secp256k1');
    if (enclavePublicKey.slice (0, 2) !== '04') {
        enclavePublicKey = '04' + enclavePublicKey;
    }

    let client_key = ec.keyFromPrivate (clientPrivateKey, 'hex');
    let enclave_key = ec.keyFromPublic (enclavePublicKey, 'hex');

    let shared_points = enclave_key.getPublic ().mul (client_key.getPrivate ());

    let y = 0x02 | (shared_points.getY ().isOdd () ? 1 : 0);
    let x = shared_points.getX ();
    let y_buffer = Buffer.from ([y]);
    let x_buffer = Buffer.from (x.toString (16), 'hex');

    let sha256 = forge.md.sha256.create ();
    sha256.update (y_buffer.toString ('binary'));
    sha256.update (x_buffer.toString ('binary'));

    return sha256.digest ().toHex ();
}

/**
 * Decrypts the encrypted message:
 * Message format: encrypted_message[*]tag[16]iv[12] (represented as: var_name[len])
 *
 * @param {string} key_hex
 * @param {string} msg
 * @returns {string}
 */
function decryptMessage (key_hex, msg) {
    let key = forge.util.hexToBytes (key_hex);
    let msg_buf = Buffer.from (msg, 'hex');
    let iv = forge.util.createBuffer (msg_buf.slice (-12).toString ('binary'));
    let tag = forge.util.createBuffer (msg_buf.slice (-28, -12).toString ('binary'));
    const decipher = forge.cipher.createDecipher ('AES-GCM', key);

    decipher.start ({ iv: iv, tag: tag });
    decipher.update (forge.util.createBuffer (msg_buf.slice (0, -28).toString ('binary')));
    if (decipher.finish ()) {
        return decipher.output.getBytes ();
    }
}

/**
 * Encrypts a message using the provided key.
 * Returns an encrypted message in this format:
 * encrypted_message[*]tag[16]iv[12] (represented as: var_name[len])
 *
 * @param {string} key_hex
 * @param {string} msg
 * @param {string} iv
 * @returns {string}
 */
function encryptMessage (key_hex, msg, iv = forge.random.getBytesSync (12)) {
    let key = forge.util.hexToBytes (key_hex);
    const cipher = forge.cipher.createCipher ('AES-GCM', key);

    cipher.start ({ iv: iv });
    cipher.update (forge.util.createBuffer (msg));
    cipher.finish ();

    let result = cipher.output.putBuffer (cipher.mode.tag).putBytes (iv);
    return result.toHex ();
}

exports.getDerivedKey = getDerivedKey;
exports.encryptMessage = encryptMessage;
exports.decryptMessage = decryptMessage;
