const { ethers } = require("hardhat");
module.exports = {
  ZERO_ADDRESS: "0x0000000000000000000000000000000000000000",
  MIN_FLOWRATE: 4294967296,
  CFA_ID: ethers.utils.keccak256(
    ethers.utils.toUtf8Bytes(
      "org.superfluid-finance.agreements.ConstantFlowAgreement.v1"
    )
  ),
};
