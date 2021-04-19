import FlightSuretyApp from "../../build/contracts/FlightSuretyApp.json";
import FlightSuretyData from "../..build/contracts/FlightSuretyData.json";
import Config from "./config.json";
import Web3 from "web3";

export default class Contract {
  constructor(network, callback) {
    let config = Config[network];
    this.web3 = new Web3(new Web3.providers.HttpProvider(config.url));
    this.flightSuretyData = new this.web3.eth.Contract(
      FlightSuretyData.abi,
      config.appAddress
    );
    this.flightSuretyApp = new this.web3.eth.Contract(
      FlightSuretyApp.abi,
      config.appAddress
    );
    this.initialize(callback);
    this.owner = null;
    this.account = null;
    this.airlines = [];
    this.flights = [];
    this.passengers = [];
  }

  initialize(callback) {
    this.web3.eth.getAccounts((error, accts) => {
      this.owner = accts[0];

      let counter = 1;

      while (this.airlines.length < 5) {
        this.airlines.push(accts[counter++]);
      }

      while (this.passengers.length < 5) {
        this.passengers.push(accts[counter++]);
      }

      callback();
    });
  }

  isOperational(callback) {
    let self = this;
    self.flightSuretyApp.methods
      .isOperational()
      .call({ from: self.owner }, callback);
  }

  setOperatingStatus(mode, callback) {
    let self = this;
    self.flightSuretyApp.methods
      .setOperatingStatus(mode)
      .send({ from: self.owner })
      .then(console.log);
  }

  fetchFlightStatus(flight, callback) {
    let self = this;
    let payload = {
      airline: self.airlines[0],
      flight: flight,
      timestamp: Math.floor(Date.now() / 1000)
    };
    self.flightSuretyApp.methods
      .fetchFlightStatus(payload.airline, payload.flight, payload.timestamp)
      .send({ from: self.owner }, (error, result) => {
        callback(error, payload);
      });
  }

  registerAirline(airline, callback) {
    let self = this;
    self.flightSuretyApp.methods
      .registerAirline(airline)
      .send({ from: this.account })
      .then(console.log);
  }

  fund(airline, callback) {
    let self = this;
    self.flightSuretyApp.methods
      .fund()
      .send({
        from: this.account,
        value: this.web3.utils.toWei(amount, "ether")
      })
      .then(console.log);
  }

  registerFlight(flightNumber, departureLocation, arrivalLocation, callback) {
    let self = this;
    let timestamp = Math.floor(date.now() / 1000);
    self.flightSuretyApp.methods
      .registerFlight(
        flightNumber,
        departureLocation,
        arrivalLocation,
        timestamp
      )
      .send({
        from: this.account,
        gas: 999999999
      })
      .then(console.log);
  }
}
