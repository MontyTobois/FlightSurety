pragma solidity ^0.5.16;

import "../node_modules/openzeppelin-solidity/contracts/math/SafeMath.sol";

contract FlightSuretyData {
  using SafeMath for uint256;

  /********************************************************************************************/
  /*                                       DATA VARIABLES                                     */
  /********************************************************************************************/

  address private contractOwner; // Account used to deploy contract
  bool private operational = true; // Blocks all state changes throughout the contract if false

  // Airlines
  struct Airline {
    uint256 funds;
    bool isFunded;
    bool isRegistered;
  }

  uint256 registeredAirlineCount = 0;
  uint256 fundedAirlineCount = 0;
  mapping(address => Airline) private airlines;

  // Flights
  struct Flight {
    bool isRegistered;
    bytes32 flightKey;
    address Airline;
    string flightNumber;
    uint8 statusCode;
    uint256 timeStamp;
    string depatureLocation;
    string arrivalLocation;
  }
  mapping(bytes32 => Flight) public flights;
  bytes32[] public registeredFlights;

  // Insurance Claims
  struct InsuranceClaim {
    address passenger;
    bytes32 insuranceKey;
    uint256 purchaseAmount;
    uint256 payoutPercent;
    bool isCredited;
  }

  mapping(bytes32 => InsuranceClaim) public flightInsuranceCliams;

  mapping(address => uint256) public returnedFunds;

  /**
   * @dev Constructor
   *      The deploying account becomes contractOwner
   */
  constructor() public {
    contractOwner = msg.sender;
    airlines[airlineAddress] = Airline(true, false, 0);
  }

  /********************************************************************************************/
  /*                                       EVENT DEFINITIONS                                  */
  /********************************************************************************************/

  event AirlineRegistered(address airline);
  event AirlineFunded(address airline);
  event FlightRegistered(bytes32 flightkeys);

  /********************************************************************************************/
  /*                                       FUNCTION MODIFIERS                                 */
  /********************************************************************************************/

  // Modifiers help avoid duplication of code. They are typically used to validate something
  // before a function is allowed to be executed.

  /**
   * @dev Modifier that requires the "operational" boolean variable to be "true"
   *      This is used on all state changing functions to pause the contract in
   *      the event there is an issue that needs to be fixed
   */
  modifier requireIsOperational() {
    require(operational, "Contract is currently not operational");
    _; // All modifiers require an "_" which indicates where the function body will be added
  }

  /**
   * @dev Modifier that requires the "ContractOwner" account to be the function caller
   */
  modifier requireContractOwner() {
    require(msg.sender == contractOwner, "Caller is not contract owner");
    _;
  }

  /**
   * @dev Modifier that requires an Airplane is not registered yet
   */
  modifier requireAirlineIsNotRegistered(address airline) {
    require(!airlines[airline].isRegistered, "Airline is already registered");
    _;
  }

  modifier requireAirlineIsNotFunded(address airline) {
    require(!airlines[airline].isFunded, "Airline is already funded");
    _;
  }

  modifier requireFlightIsNotRegistered(bytes32 flightKey) {
    require(!flights[flightKey].isRegistered, "Flight is already registered");
    _;
  }

  modifier requireAirlineIsRegistered(address airline) {
    require(airlines[airline].isRegistered, "Airline is not registered");
    _;
  }

  modifier requireAirlineIsFunded(address airline) {
    require(airlines[airline].isFunded, "Airline is not funded");
    _;
  }

  modifier requireFlightIsRegistered(bytes32 flightKey) {
    require(flights[flightKey].isRegistered, "Flight is not registered");
    _;
  }

  modifier requireInsuranceNotCredited(bytes32 insuranceKey) {
    require(
      !flightInsuranceCliams[insuranceKey].isCredited,
      "Refund was credited for ticket"
    );
    _;
  }

  modifier requireInsuranceCredited(bytes32 insuranceKey) {
    require(
      flightInsuranceCliams[insuranceKey].isCredited,
      "Refund has not been credited for ticket"
    );
    _;
  }

  /********************************************************************************************/
  /*                                       UTILITY FUNCTIONS                                  */
  /********************************************************************************************/

  /**
   * @dev Get operating status of contract
   *
   * @return A bool that is the current operating status
   */
  function isOperational() public view returns (bool) {
    return operational;
  }

  /**
   * @dev Sets contract operations on/off
   *
   * When operational mode is disabled, all write transactions except for this one will fail
   */
  function setOperatingStatus(bool mode) external requireContractOwner {
    operational = mode;
  }

  /********************************************************************************************/
  /*                                     SMART CONTRACT FUNCTIONS                             */
  /********************************************************************************************/

  function isAirlineRegistered(address airline)
    public
    view
    requireIsOperational
    returns (bool)
  {
    return airlines[airline].isRegistered;
  }

  function isAirlineFunded(address airline) public view returns (bool) {
    return airlines[airline].isFunded;
  }

  function isFlightRegistered(bytes32 flightKey) public view returns (bool) {
    return flights[flightKey].isRegistered;
  }

  function getRegisteredAirlineCount()
    public
    view
    requireIsOperational
    returns (uint256)
  {
    return registeredAirlineCount;
  }

  function getFundedAirlineCount()
    public
    view
    requireIsOperational
    returns (uint256)
  {
    return fundedAirlineCount;
  }

  function getRegisteredFlightCount()
    public
    view
    requireIsOperational
    returns (uint256)
  {
    return registeredFlights.length;
  }

  /**
   * @dev Add an airline to the registration queue
   *      Can only be called from FlightSuretyApp contract
   *
   */
  function registerAirline(address newAirline, address registeringAirline)
    external
    requireIsOperational
    requireAirlineIsNotRegistered(newAirline)
    requireAirlineIsFunded(registeringAirline)
  {
    airlines[newAirline] = Airline(true, false, 0);
    registeredAirlineCount = registeredAirlineCount.add(1);
    emit AirlineRegistered(newAirline);
  }

  function registerFlight(
    bytes32 flightKey,
    uint256 timestamp,
    address airline,
    string memory flightNumber,
    string memory departureLocation,
    string memory arrivalLocation
  )
    public
    payable
    requireIsOperational
    requireAirlineIsFunded(airline)
    requireFlightIsNotRegistered(flightKey)
  {
    flights[flightKey] = Flight(
      true,
      flightKey,
      airline,
      flightNumber,
      0,
      timestamp,
      departureLocation,
      arrivalLocation
    );
    registeredFlights.push(flightKey);
    emit FlightRegistered(flightKey);
  }

  /**
   * @dev Buy insurance for a flight
   *
   */
  function buy() external payable {}

  /**
   *  @dev Credits payouts to insurees
   */
  function creditInsurees() external pure {}

  /**
   *  @dev Transfers eligible payout funds to insuree
   *
   */
  function pay() external pure {}

  /**
   * @dev Initial funding for the insurance. Unless there are too many delayed flights
   *      resulting in insurance payouts, the contract should be self-sustaining
   *
   */
  function fund() public payable {}

  function getFlightKey(
    address airline,
    string memory flight,
    uint256 timestamp
  ) internal pure returns (bytes32) {
    return keccak256(abi.encodePacked(airline, flight, timestamp));
  }

  /**
   * @dev Fallback function for funding smart contract.
   *
   */
  function() external payable {
    fund();
  }
}
