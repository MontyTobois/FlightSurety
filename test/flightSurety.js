var Test = require("../config/testConfig.js");
var Web3 = require("web3");
var BigNumber = require("bignumber.js");
// var fs = require("fs-extra");

contract("Flight Surety Tests", async (accounts) => {
  var web3;
  var config;
  before("setup contract", async () => {
    config = await Test.Config(accounts);
    web3 = new Web3(new Web3.providers.HttpProvider(config.url));
    // await config.flightSuretyData.authorizeCaller(
    //   config.flightSuretyApp.address
    // );
  });

  /****************************************************************************************/
  /* Operations and Settings                                                              */
  /****************************************************************************************/

  it(`(multiparty) has correct initial isOperational() value`, async function () {
    // Get operating status
    let status = await config.flightSuretyData.isOperational.call();
    assert.equal(status, true, "Incorrect initial operating status value");
  });

  it(`(multiparty) can block access to setOperatingStatus() for non-Contract Owner account`, async function () {
    // Ensure that access is denied for non-Contract Owner account
    let accessDenied = false;
    try {
      await config.flightSuretyData.setOperatingStatus(false, {
        from: config.testAddresses[2]
      });
    } catch (e) {
      accessDenied = true;
    }
    assert.equal(accessDenied, true, "Access not restricted to Contract Owner");
  });

  it(`(multiparty) can allow access to setOperatingStatus() for Contract Owner account`, async function () {
    // Ensure that access is allowed for Contract Owner account
    let accessDenied = false;
    try {
      await config.flightSuretyData.setOperatingStatus(false);
    } catch (e) {
      accessDenied = true;
    }
    assert.equal(
      accessDenied,
      false,
      "Access not restricted to Contract Owner"
    );
  });

  it(`(multiparty) can block access to functions using requireIsOperational when operating status is false`, async function () {
    await config.flightSuretyData.setOperatingStatus(false);

    let reverted = false;
    try {
      await config.flightSurety.setTestingMode(true);
    } catch (e) {
      reverted = true;
    }
    assert.equal(reverted, true, "Access not blocked for requireIsOperational");

    // Set it back for other tests to work
    await config.flightSuretyData.setOperatingStatus(true);
  });

  it("(airline) cannot register an Airline using registerAirline() if it is not funded", async () => {
    // ARRANGE
    let newAirline = accounts[2];

    // ACT
    try {
      await config.flightSuretyApp.registerAirline(newAirline, {
        from: config.firstAirline
      });
    } catch (e) {}
    let result = await config.flightSuretyData.isAirlineRegistered.call(
      newAirline
    );

    // ASSERT
    assert.equal(
      result,
      false,
      "Airline should not be able to register another airline if it hasn't provided funding"
    );
  });

  it("(airline) cannot register a flight using registerFlight if not funded", async () => {
    // ARRANGE
    let flightName = "Flight Run";
    let departureTime = Date.now();
    let destination = "Egypt, Africa";
    let flightKey = "";

    //  ACT
    try {
      flightKey = await config.flightSuretyApp.registerFlight(
        flightName,
        departureTime,
        destination,
        { from: config.firstAirline }
      );
    } catch (error) {
      let result = await config.flightSuretyData.isFlightRegistered.call(
        web3.utils.toHex(flightKey)
      );

      // ASSERT
      assert.equal(
        result,
        false,
        "Airline should not ne able to register another airline if there is not sufficent funding"
      );
    }
  });

  it("(airline) can fund itself using fund()", async () => {
    // ARRANGE
    let amount = web3.utils.toWei("10", "ether");
    let result = true;

    //ACT
    try {
      result = await config.flightSuretyApp.fund.call({
        from: config.firstAirline,
        value: amount
      });
    } catch (error) {
      // console.log(error);
    }

    // ASSERT
    assert.equal(result, true, "Air has insufficent funds");
  });

  it("(airline) can register another airline using reigsterAirline()", async () => {
    // ARRANGE
    let newAirline = accounts[2];
    let result = true;

    // ACT
    try {
      await config.flightSuretyApp.fund({
        from: config.firstAirline,
        value: web3.utils.toWei("10", "ether")
      });
      await config.flightSuretyApp.registerAirline(newAirline, {
        from: config.firstAirline
      });
    } catch (error) {
      // console.log(error);
    }
    result = await config.flightSuretyData.isAirlineRegistered.call(newAirline);
    // ASSERT
    assert.equal(
      result,
      false,
      "Airline should register another airline once sufficent fund have been applied"
    );
  });

  // it("('flight') will credit passenger using the ");
});
