const expectEvent = require("openzeppelin-solidity/test/helpers/expectEvent");
const {expectThrow} = require("openzeppelin-solidity/test/helpers/expectThrow");
const {padLeft, padRight} = require("./helpers/pad");

const RequestableSimpleToken = artifacts.require("./RequestableSimpleToken.sol");

require('chai')
  .use(require('chai-bignumber')(web3.BigNumber))
  .should();


contract("RequestableSimpleToken", (accounts) => {
  const [
    owner,
    nextOwner,
    holder,
    other,
  ] = accounts;

  const tokenAmount = 1e18;

  let token;

  before(async () => {
    token = await RequestableSimpleToken.deployed();

    await token.mint(holder, tokenAmount);
  });

  describe("request on owner", () => {
    const trieKey = padLeft("0x00");
    const trieValue = padRight(owner);

    describe("#Enter", () => {
      const isExit = false;

      it("only owner in root chain can make an enter request", async () => {
        await expectThrow(
          token.applyRequestInRootChain(isExit, 0, other, trieKey, trieValue)
        );

        const e = await expectEvent.inTransaction(
          token.applyRequestInRootChain(isExit, 0, owner, trieKey, trieValue),
          "Request",
        );
      });

      it("owner in child chain should be updated", async () => {
        const trieValue = padRight(nextOwner);
        const e = await expectEvent.inTransaction(
          token.applyRequestInChildChain(isExit, 0, nextOwner, trieKey, trieValue),
          "Request",
        );

        (await token.owner()).should.be.equal(nextOwner);
      });

      after(async () => {
        // restore owner
        await token.transferOwnership(owner, { from: nextOwner });
      });
    });

    describe("#Exit", () => {
      const isExit = true;

      it("only owner in child chain can make a exit request", async () => {
        const trieValue = padRight(nextOwner);
        const e = await expectEvent.inTransaction(
          token.applyRequestInChildChain(isExit, 0, owner, trieKey, trieValue),
          "Request",
        );
      });

      it("owner in root chain should be updated", async () => {
        const e = await expectEvent.inTransaction(
          token.applyRequestInRootChain(isExit, 0, nextOwner, trieKey, trieValue),
          "Request",
        );

        (await token.owner()).should.be.equal(nextOwner);
      });
    });
  });
});
