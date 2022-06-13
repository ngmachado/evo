const { ethers, network } = require("hardhat");
const BN = require("bn.js");

const expectedRevert = async (
  fn,
  revertMsg,
  printError = false,
  nestedError = false
) => {
  try {
    await fn;
    return false;
  } catch (err) {
    if (printError) console.log(err);
    if (nestedError) {
      return err.errorObject.errorObject.error.toString().includes(revertMsg);
    }
    return err.toString().includes(revertMsg);
  }
};

const mintAndUpgrade = async (env, account, amount = "1000") => {
  await env.tokens.dai.mint(
    account.address,
    ethers.utils.parseUnits(amount, 18)
  );
  await env.tokens.dai
    .connect(account)
    .approve(env.tokens.daix.address, ethers.utils.parseEther(amount));
  const daixUpgradeOperation = env.tokens.daix.upgrade({
    amount: ethers.utils.parseEther(amount),
  });
  await daixUpgradeOperation.exec(account);
};

const getFlowRate = async (env, sender, receiver) => {
  return await env.sf.cfaV1.getFlow({
    superToken: env.tokens.daix.address,
    sender: sender,
    receiver: receiver,
    providerOrSigner: env.accounts[0],
  });
};

const createStream = async (
  env,
  account,
  receiver,
  flowRate
) => {
  const op = env.sf.cfaV1.createFlow({
    receiver: receiver,
    superToken: env.tokens.daix.address,
    flowRate: flowRate,
  });

  return await op.exec(account);
};

const updateStream = async (
  env,
  account,
  receiver,
  flowRate
) => {
  const op = env.sf.cfaV1.updateFlow({
    receiver: receiver,
    superToken: env.tokens.daix.address,
    flowRate: flowRate,
  });

  return await op.exec(account);
};

const deleteStream = async (
  env,
  account,
  receiver
) => {
  const op = env.sf.cfaV1.deleteFlow({
    sender: account.address,
    receiver: receiver,
    superToken: env.tokens.daix.address,
  });

  return await op.exec(account);
};

const isAppJailed = async (env, app) => {
  return env.host.isAppJailed(app);
};
const advTime = async (seconds = 3600) => {
  await network.provider.send("evm_increaseTime", [seconds]);
  await network.provider.send("evm_mine");
};

const toBN = (a) => {
  return new BN(a);
}

module.exports = {
  expectedRevert,
  mintAndUpgrade,
  getFlowRate,
  createStream,
  updateStream,
  deleteStream,
  isAppJailed,
  advTime,
  toBN,
};
