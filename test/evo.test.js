const { assert } = require("chai");
const { deployTestEnv } = require("./utils/setTestEnv");
const { network, ethers } = require("hardhat");
const f = require("./utils/helperFuncs");

let env;

const uri = [
  "https://ipfs.io/ipfs/QmULZERZVPcJpXiUk3vGvQHPDyy9UFgpKP7XhPRHxvKUSJ",
  "https://ipfs.io/ipfs/QmNQKJU3RwNEfT9yMLoGp3kbiqv7umwTczhZKReUdEy1Fi",
  "https://ipfs.io/ipfs/QmQ6aWY4cGTLQgTrBVjMfGrQUhpS61mSFdcEoKwadqiK2V",
  "https://ipfs.io/ipfs/QmVLe8QuqLi99PwBP91QFT256kmYKpnaeBjzN1XmHyqKjo",
  "https://ipfs.io/ipfs/QmNr9wZYtj6YSaX1x9rGUVMKLRuHC1cSo6PS6e3vXFH92c",
];

const getAgreementId = (userAddr, evoAddr) => {
  const encodedData = ethers.utils.defaultAbiCoder.encode(
    ["address", "address"],
    [userAddr, evoAddr]
  );
  return ethers.utils.keccak256(encodedData);
};

const increaseTime = async (seconds) => {
  await network.provider.send("evm_increaseTime", [seconds]);
  await network.provider.send("evm_mine");
};

before(async function () {
  env = await deployTestEnv();
  await f.mintAndUpgrade(env, env.accounts[0]);
});

describe("⏬ Evo", function () {
  it("#1.1 - deploy and evo", async () => {
    const evo = await env.factories.evo.deploy(
      "evo",
      "evo",
      env.tokens.daix.address,
      env.host.address,
      "1000000000"
    );
    await f.createStream(
      env,
      env.accounts[0],
      evo.address,
      "1000000000"
    );
    const id = getAgreementId(env.accounts[0].address, evo.address);
    let paragon = await evo.getParagon(id);
    let tokenUri = await evo.tokenURI(id);
    assert.equal(paragon.toString(), "1", "paragon should be 1");
    assert.equal(tokenUri.toString(), uri[0], "wrong uri");
    await increaseTime(3600 * 24 * 30 * 12 * 50);
    paragon = await evo.getParagon(id);
    tokenUri = await evo.tokenURI(id);
    assert.equal(paragon.toString(), "2", "paragon should be 2");
    assert.equal(tokenUri.toString(), uri[1], "wrong uri");
    // lets go to last evo
    await increaseTime(3600 * 24 * 30 * 12 * 1000);
    paragon = await evo.getParagon(id);
    tokenUri = await evo.tokenURI(id);
    assert.equal(paragon.toString(), "5", "paragon should be 5");
    assert.equal(tokenUri.toString(), uri[4], "wrong uri");
  });
  it("#1.2 - evo start and restart", async () => {
    const evo = await env.factories.evo.deploy(
      "evo",
      "evo",
      env.tokens.daix.address,
      env.host.address,
      "1000000000"
    );
    await f.createStream(
      env,
      env.accounts[0],
      evo.address,
      "1000000000"
    );
    await increaseTime(3600 * 24 * 30 * 12 * 50);
    const id = getAgreementId(env.accounts[0].address, evo.address);
    let paragon = await evo.getParagon(id);
    let tokenUri = await evo.tokenURI(id);
    assert.equal(paragon.toString(), "2", "paragon should be 2");
    assert.equal(tokenUri.toString(), uri[1], "wrong uri");
    await f.deleteStream(
      env,
      env.accounts[0],
      evo.address
    );
    await increaseTime(3600 * 24 * 30 * 12 * 50);
    paragon = await evo.getParagon(id);
    tokenUri = await evo.tokenURI(id);
    assert.equal(paragon.toString(), "2", "paragon should be 2");
    assert.equal(tokenUri.toString(), uri[1], "wrong uri");
    await f.createStream(
      env,
      env.accounts[0],
      evo.address,
      "1000000000"
    );
    paragon = await evo.getParagon(id);
    tokenUri = await evo.tokenURI(id);
    assert.equal(paragon.toString(), "2", "paragon should be 2");
    assert.equal(tokenUri.toString(), uri[1], "wrong uri");
  });
});
