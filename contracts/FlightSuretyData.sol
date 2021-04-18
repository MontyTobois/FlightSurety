pragma solidity ^0.5.16;

import "../node_modules/openzeppelin-solidity/contracts/math/SafeMath.sol";

contract FlightSuretyData {
  using SafeMath for uint256;

  /********************************************************************************************/
  /*                                       DATA VARIABLES                                     */
  /********************************************************************************************/

  address private contractOwner; // Account used to deploy contract
  bool private operational = true; // Blocks all state changes throughout the contract if false
  mapping(address => uint256) private authorizedContracts;

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
    uint256 purchaseAmount;
    uint256 payoutPercent;
    bool isCredited;
  }

  mapping(bool => InsuranceClaim[]) public creditedGroup;

  // Flight Insurance Claims
  mapping(bytes32 => InsuranceClaim[]) public flightInsuranceClaims;

  // Passenger Insurance Claims
  mapping(address => uint256) public returnedFunds;

  /**
   * @dev Constructor
   *      The deploying account becomes contractOwner
   */
  constructor(address airlineAddress) public {
    contractOwner = msg.sender;
    airlines[airlineAddress] = Airline(0, true, false);
  }

  /********************************************************************************************/
  /*                                       EVENT DEFINITIONS                                  */
  /********************************************************************************************/

  event AirlineRegistered(address airline);
  event AirlineFunded(address airline);
  event FlightRegistered(bytes32 flightkeys);
  event ProcessedFlightStatus(bytes32 flightKey, uint8 statusCode);
  event PassengerInsured(
    bytes32 flightKey,
    address passenger,
    uint256 amount,
    uint256 payout
  );
  event CreditInsuree(bytes32 flightKey, address passenger, uint256 amount);
  event PayInsuree(address payoutAddress, uint256 amount);

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
   * @dev Modifier that checks if caller is authorized
   */
  modifier requireIsCallerAuthorized() {
    require(authorizedContracts[msg.sender] == 1, "caller is not authorized");
    _;
  }

  /**
   * @dev Modifier that requires an Airline is not registered yet
   */
  modifier requireAirlineIsNotRegistered(address airline) {
    require(!airlines[airline].isRegistered, "Airline is already registered");
    _;
  }

  /**
   * @dev Modifier that requires an Airline is not funded yet
   */
  modifier requireAirlineIsNotFunded(address airline) {
    require(!airlines[airline].isFunded, "Airline is already funded");
    _;
  }

  /**
   * @dev Modifier that checks if Airline is registered yet
   */
  modifier requireAirlineIsRegistered(address airline) {
    require(airlines[airline].isRegistered, "Airline is not registered");
    _;
  }

  /**
   * @dev Modifier that checks if Airline is funded yet
   */
  modifier requireAirlineIsFunded(address airline) {
    require(airlines[airline].isFunded, "Airline is not funded");
    _;
  }

  /**
   * @dev Modifier that checks Flight is not registered yet
   */
  modifier requireFlightIsNotRegistered(bytes32 flightKey) {
    require(!flights[flightKey].isRegistered, "Flight is already registered");
    _;
  }

  /**
   * @dev Modifier that checks if Flight is registered yet
   */
  modifier requireFlightIsRegistered(bytes32 flightKey) {
    require(flights[flightKey].isRegistered, "Flight is not registered");
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
  /**
   * @dev Checks if airline is registered
   * returns (true/false)
   */
  function isAirlineRegistered(address airline)
    public
    view
    requireIsOperational
    requireIsCallerAuthorized
    returns (bool)
  {
    return airlines[airline].isRegistered;
  }

  /**
   * @dev Checks if airline is funded
   * returns (true/false)
   */
  function isAirlineFunded(address airline) public view returns (bool) {
    return airlines[airline].isFunded;
  }

  /**
   * @dev Checks if flight is registered
   * returns (true/false)
   */
  function isFlightRegistered(bytes32 flightKey) public view returns (bool) {
    return flights[flightKey].isRegistered;
  }

  /**
   * @dev Checks if airline is funded
   * returns (true/false)
   */
  function isFlightLanded(bytes32 flightKey) public view returns (bool) {
    if (flights[flightKey].statusCode > 0) {
      return true;
    }
    return false;
  }

  function flightInsuredForPassenger(bytes32 flightKey, address passenger)
    public
    view
    returns (bool)
  {
    InsuranceClaim[] memory insuranceClaims = flightInsuranceClaims[flightKey];
    for (uint256 i = 0; i < insuranceClaims.length; i++) {
      if (insuranceClaims[i].passenger == passenger) {
        return true;
      }
    }
  }

  /**
   * @dev Gets the number of airlines already registered
   * returns number of registered airlines
   */
  function getRegisteredAirlineCount()
    public
    view
    requireIsOperational
    requireIsCallerAuthorized
    returns (uint256)
  {
    return registeredAirlineCount;
  }

  /**
   * @dev Gets the number of airlines already funded
   * returns number of funded airlines
   */
  function getFundedAirlineCount()
    public
    view
    requireIsOperational
    requireIsCallerAuthorized
    returns (uint256)
  {
    return fundedAirlineCount;
  }

  /**
   * @dev Gets the number of flights already registered
   * returns number of registered flights
   */
  function getRegisteredFlightCount()
    public
    view
    requireIsOperational
    requireIsCallerAuthorized
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
    requireIsCallerAuthorized
    requireAirlineIsNotRegistered(newAirline)
    requireAirlineIsFunded(registeringAirline)
  {
    airlines[newAirline] = Airline(0, true, false);
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
    requireIsCallerAuthorized
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
   * @dev Determines the status for flight
   * returns status code for flight
   */
  function processFlightStatus(
    address airline,
    string calldata flight,
    uint256 timestamp,
    uint8 statusCode
  ) external requireIsOperational requireIsCallerAuthorized {
    bytes32 flightKey = getFlightKey(airline, flight, timestamp);
    require(!isFlightLanded(flightKey), "Flight has landed already.");
    if (flights[flightKey].statusCode == 0) {
      flights[flightKey].statusCode = statusCode;
      if (statusCode == 20) {
        creditInsurees(flightKey);
      }
    }
    emit ProcessedFlightStatus(flightKey, statusCode);
  }

  /**
   * @dev Buy insurance for a flight
   *
   */
  function buy(
    bytes32 flightKey,
    address passenger,
    uint256 amount,
    uint256 payout
  ) external payable requireIsOperational requireIsCallerAuthorized {
    require(isFlightRegistered(flightKey), "Flight is already registered");
    require(!isFlightLanded(flightKey), "Flight has already landed");

    flightInsuranceClaims[flightKey].push(
      InsuranceClaim(passenger, amount, payout, false)
    );
    emit PassengerInsured(flightKey, passenger, amount, payout);
  }

  /**
   *  @dev Credits payouts to insurees
   */
  function creditInsurees(bytes32 flightKey)
    internal
    requireIsOperational
    requireIsCallerAuthorized
  {
    for (uint256 i = 0; i < flightInsuranceClaims[flightKey].length; i++) {
      InsuranceClaim memory insuranceClaim =
        flightInsuranceClaims[flightKey][i];
      insuranceClaim.isCredited = true;
      uint256 amount =
        insuranceClaim.purchaseAmount.mul(insuranceClaim.payoutPercent).div(
          100
        );
      returnedFunds[insuranceClaim.passenger] = returnedFunds[
        insuranceClaim.passenger
      ]
        .add(amount);
      emit CreditInsuree(flightKey, insuranceClaim.passenger, amount);
    }
  }

  /**
   *  @dev Transfers eligible payout funds to insuree
   *
   */
  function pay(address payable payoutAddress)
    external
    payable
    requireIsOperational
    requireIsCallerAuthorized
  {
    uint256 amount = returnedFunds[payoutAddress];
    require(address(this).balance >= amount, "Contract has insufficentt funds");
    require(amount > 0, "No funds avaiable for withdraw");
    returnedFunds[payoutAddress] = 0;
    address(uint160(address(payoutAddress))).transfer(amount);
    emit PayInsuree(payoutAddress, amount);
  }

  /**
   * @dev Initial funding for the insurance. Unless there are too many delayed flights
   *      resulting in insurance payouts, the contract should be self-sustaining
   *
   */
  function fund(address airline, uint256 amount)
    external
    requireIsOperational
    requireIsCallerAuthorized
    requireAirlineIsRegistered(airline)
    requireAirlineIsNotFunded(airline)
    returns (bool)
  {
    airlines[airline].isFunded = true;
    airlines[airline].funds = airlines[airline].funds.add(amount);
    fundedAirlineCount = fundedAirlineCount.add(1);
    emit AirlineFunded(airline);
    return airlines[airline].isFunded;
  }

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
  function() external payable {}
}
