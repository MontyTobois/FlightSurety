pragma solidity ^0.5.16;

// It's important to avoid vulnerabilities due to numeric overflow bugs
// OpenZeppelin's SafeMath library, when used correctly, protects agains such bugs
// More info: https://www.nccgroup.trust/us/about-us/newsroom-and-events/blog/2018/november/smart-contract-insecurity-bad-arithmetic/

import "../node_modules/openzeppelin-solidity/contracts/math/SafeMath.sol";

/************************************************** */
/* FlightSurety Smart Contract                      */
/************************************************** */
contract FlightSuretyApp {
  using SafeMath for uint256; // Allow SafeMath functions to be called for all uint256 types (similar to "prototype" in Javascript)

  /********************************************************************************************/
  /*                                       DATA VARIABLES                                     */
  /********************************************************************************************/

  // Flight status codees
  uint8 private constant STATUS_CODE_UNKNOWN = 0;
  uint8 private constant STATUS_CODE_ON_TIME = 10;
  uint8 private constant STATUS_CODE_LATE_AIRLINE = 20;
  uint8 private constant STATUS_CODE_LATE_WEATHER = 30;
  uint8 private constant STATUS_CODE_LATE_TECHNICAL = 40;
  uint8 private constant STATUS_CODE_LATE_OTHER = 50;

  address private contractOwner; // Account used to deploy contract

  bool private operational = true;

  // Airline can be registered with a fee of 10 ether being submitted
  uint256 AIRLINE_REGISTRATION_FEE = 10 ether;

  // Passenger may spend up to 1 ether to purchase flight insurance
  uint256 MAX_INSURANCE_VALUE = 1 ether;

  // Insurance multipler in percentage
  uint256 INSURANCE_PAYOUT = 150; // 150%

  // Registration of fifth and subsequent airlines requires mutli-party consensus of 50% registered airlines
  uint256 MULTI_CALL_AIRLINE_VOTING_THRESHOLD = 4;
  uint256 AIRLINE_REGISTRATION_REQUIURED_VOTES = 2;

  // Pending Airlines
  struct pendingAirline {
    bool isRegistered;
    bool isFunded;
  }

  mapping(address => address[]) public pendingAirlines;

  // FlightSurety Data Contract
  FlightSuretyData flightSuretyData;

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
    // Modify to call data contract's status
    require(true, "Contract is currently not operational");
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
   * @dev Modifier that requires an Airline is not registered yet
   */
  modifier requireAirlineIsNotRegistered(address airline) {
    require(
      !flightSuretyData.isAirlineRegistered(airline),
      "Airline is already registered"
    );
    _;
  }

  /**
   * @dev Modifier that requires an Airline is not funded yet
   */
  modifier requireAirlineIsNotFunded(address airline) {
    require(
      !flightSuretyData.isAirlineFunded(airline),
      "Airline is already funded"
    );
    _;
  }

  /**
   * @dev Modifier that requires an Airline is registered
   */
  modifier requireAirlineIsRegistered(address airline) {
    require(
      flightSuretyData.isAirlineRegistered(airline),
      "Airline is not registered"
    );
    _;
  }

  /**
   * @dev Modifier that requires an Airline to be funded
   */
  modifier requireAirlineIsFunded(address airline) {
    require(flightSuretyData.isAirlineFunded(airline), "Airline is not funded");
    _;
  }

  /**
- @dev Modifier that requires funding is adequate
   */
  modifier requireAdequateFunding(uint256 amount) {
    require(msg.value >= amount, "Inadequate Funds");
    _;
  }

  /**
- @dev Modifier that returns change after airline  is funded
   */
  modifier refundAmount() {
    _;
    uint256 refund = msg.value - AIRLINE_REGISTRATION_FEE;
    msg.sender.transfer(refund);
  }

  /**
   * @dev Modifier that checks Flight is not registered yet
   */
  modifier requireFlightIsNotRegistered(bytes32 flightKey) {
    require(
      !flightSuretyData.isFlightRegistered(flightKey),
      "Flight is already registered"
    );
    _;
  }

  /**
   * @dev Modifier that requires a Flight is registered
   */
  modifier requireFlightIsRegistered(bytes32 flightKey) {
    require(
      flightSuretyData.isFlightRegistered(flightKey),
      "Flight is not registered"
    );
    _;
  }

  /**
   * @dev Modifier that requires a Flight has not landed
   */
  modifier requireFlightIsNotLanded(bytes32 flightKey) {
    require(
      !flightSuretyData.isFlightLanded(flightKey),
      "Flight is not registered"
    );
    _;
  }

  /**
   * @dev Modifier that requires a Flight is not insured
   */
  modifier requireFlightIsNotInsured(bytes32 flightKey, address passenger) {
    require(
      !flightSuretyData.flightInsuredForPassenger(flightKey, passenger),
      "Flight is insured already"
    );
    _;
  }

  /**
   * @dev Modifier that requires the value spent on insurance is not exceeded
   */
  modifier requireLowerInsuranceValue() {
    require(
      msg.value <= MAX_INSURANCE_VALUE,
      "Value is higher than max insurance plan"
    );
    _;
  }

  /********************************************************************************************/
  /*                                       CONSTRUCTOR                                        */
  /********************************************************************************************/

  /**
   * @dev Contract constructor
   *
   */
  constructor(address payable contractData) public {
    contractOwner = msg.sender;
    flightSuretyData = FlightSuretyData(contractData);
  }

  /********************************************************************************************/
  /*                                       UTILITY FUNCTIONS                                  */
  /********************************************************************************************/

  function isOperational() public view requireContractOwner returns (bool) {
    return operational; // Modify to call data contract's status
  }

  /********************************************************************************************/
  /*                                     SMART CONTRACT FUNCTIONS                             */
  /********************************************************************************************/

  /**
   * @dev Add an airline to the registration queue
   *
   */
  function registerAirline(address airline)
    external
    requireIsOperational
    requireAirlineIsNotRegistered(airline) // Airline is not registered yet
    requireAirlineIsFunded(msg.sender) // Voter is a funded airline
    returns (
      bool success,
      uint256 votes,
      uint256 registeredAirlineCount
    )
  {
    // If less than required minimum airlines for voting process
    if (
      flightSuretyData.getRegisteredAirlineCount() <=
      MULTI_CALL_AIRLINE_VOTING_THRESHOLD
    ) {
      flightSuretyData.registerAirline(airline, msg.sender);
      return (success, 0, flightSuretyData.getRegisteredAirlineCount());
    } else {
      // Check for duplicates
      bool doubleVote = false;
      for (uint256 i = 0; i < pendingAirlines[airline].length; i++) {
        if (pendingAirlines[airline][i] == msg.sender) {
          doubleVote = true;
          break;
        }
      }
      require(
        !doubleVote,
        "Duplicate vote, you cannot vote for the same airline twice."
      );
      pendingAirlines[airline].push(msg.sender);
      // Check if enough votes to register airline
      if (
        pendingAirlines[airline].length >=
        flightSuretyData.getRegisteredAirlineCount().div(
          AIRLINE_REGISTRATION_REQUIURED_VOTES
        )
      ) {
        flightSuretyData.registerAirline(airline, msg.sender);
        return (
          true,
          pendingAirlines[airline].length,
          flightSuretyData.getRegisteredAirlineCount()
        );
      }
      return (
        false,
        pendingAirlines[airline].length,
        flightSuretyData.getRegisteredAirlineCount()
      );
    }
  }

  /**
   * @dev Funds an registered airline
   *
   */
  function fund()
    external
    payable
    requireIsOperational
    requireAirlineIsRegistered(msg.sender)
    requireAirlineIsNotFunded(msg.sender)
    requireAdequateFunding(AIRLINE_REGISTRATION_FEE)
    returns (bool)
  {
    address(uint160(address(flightSuretyData))).transfer(
      AIRLINE_REGISTRATION_FEE
    );
    return flightSuretyData.fund(msg.sender, AIRLINE_REGISTRATION_FEE);
  }

  /**
   * @dev Register a future flight for insuring.
   *
   */
  function registerFlight(
    uint256 timestamp,
    string calldata flightNumber,
    string calldata departureLocation,
    string calldata arrivalLocation
  ) external requireIsOperational requireAirlineIsFunded(msg.sender) {
    bytes32 flightKey = getFlightKey(msg.sender, flightNumber, timestamp);
    flightSuretyData.registerFlight(
      flightKey,
      timestamp,
      msg.sender,
      flightNumber,
      departureLocation,
      arrivalLocation
    );
  }

  /**
   * @dev Called after oracle has updated flight status
   *
   */
  function processFlightStatus(
    address airline,
    string memory flight,
    uint256 timestamp,
    uint8 statusCode
  ) internal requireIsOperational {
    flightSuretyData.processFlightStatus(
      airline,
      flight,
      timestamp,
      statusCode
    );
  }

  /**
   * @dev Generate a request for oracles to fetch flight information
   *
   */
  function fetchFlightStatus(
    address airline,
    string calldata flight,
    uint256 timestamp,
    bytes32 flightKey
  )
    external
    requireFlightIsRegistered(flightKey)
    requireFlightIsNotLanded(flightKey)
  {
    uint8 index = getRandomIndex(msg.sender);

    // Generate a unique key for storing the request
    bytes32 key =
      keccak256(abi.encodePacked(index, airline, flight, timestamp));
    oracleResponses[key] = ResponseInfo({requester: msg.sender, isOpen: true});

    emit OracleRequest(index, airline, flight, timestamp);
  }

  /**
   * @dev Buys insurance for a flight
   *
   */
  function buy(bytes32 flightKey)
    external
    payable
    requireIsOperational
    requireFlightIsRegistered(flightKey)
    requireFlightIsNotLanded(flightKey)
    requireFlightIsNotInsured(flightKey, msg.sender)
    requireLowerInsuranceValue()
  {
    address(uint160(address(flightSuretyData))).transfer(msg.value);
    flightSuretyData.buy(flightKey, msg.sender, msg.value, INSURANCE_PAYOUT);
  }

  /**
   * @dev Transfers eligible payout funds to insuree
   *
   */
  function pay() public {
    flightSuretyData.pay(msg.sender);
  }

  /********************************************************************************************/
  /*                                     ORACLE MANAGEMENT                                   */
  /********************************************************************************************/

  // Incremented to add pseudo-randomness at various points
  uint8 private nonce = 0;

  // Fee to be paid when registering oracle
  uint256 public constant REGISTRATION_FEE = 1 ether;

  // Number of oracles that must respond for valid status
  uint256 private constant MIN_RESPONSES = 3;

  struct Oracle {
    bool isRegistered;
    uint8[3] indexes;
  }

  // Track all registered oracles
  mapping(address => Oracle) private oracles;

  // Model for responses from oracles
  struct ResponseInfo {
    address requester; // Account that requested status
    bool isOpen; // If open, oracle responses are accepted
    mapping(uint8 => address[]) responses; // Mapping key is the status code reported
    // This lets us group responses and identify
    // the response that majority of the oracles
  }

  // Track all oracle responses
  // Key = hash(index, flight, timestamp)
  mapping(bytes32 => ResponseInfo) private oracleResponses;

  // Event fired each time an oracle submits a response
  event FlightStatusInfo(
    address airline,
    string flight,
    uint256 timestamp,
    uint8 status
  );

  event OracleReport(
    address airline,
    string flight,
    uint256 timestamp,
    uint8 status
  );

  // Event fired when flight status request is submitted
  // Oracles track this and if they have a matching index
  // they fetch data and submit a response
  event OracleRequest(
    uint8 index,
    address airline,
    string flight,
    uint256 timestamp
  );

  event OracleRegistered(address oracle);

  // Register an oracle with the contract
  function registerOracle() external payable requireIsOperational {
    // Require registration fee
    require(msg.value >= REGISTRATION_FEE, "Registration fee is required");

    uint8[3] memory indexes = generateIndexes(msg.sender);

    oracles[msg.sender] = Oracle({isRegistered: true, indexes: indexes});

    emit OracleRegistered(msg.sender);
  }

  function getMyIndexes()
    external
    view
    requireIsOperational
    returns (uint8[3] memory)
  {
    require(oracles[msg.sender].isRegistered, "Not registered as an oracle");

    return oracles[msg.sender].indexes;
  }

  // Called by oracle when a response is available to an outstanding request
  // For the response to be accepted, there must be a pending request that is open
  // and matches one of the three Indexes randomly assigned to the oracle at the
  // time of registration (i.e. uninvited oracles are not welcome)
  function submitOracleResponse(
    uint8 index,
    address airline,
    string calldata flight,
    uint256 timestamp,
    uint8 statusCode
  ) external requireIsOperational {
    require(
      (oracles[msg.sender].indexes[0] == index) ||
        (oracles[msg.sender].indexes[1] == index) ||
        (oracles[msg.sender].indexes[2] == index),
      "Index does not match oracle request"
    );

    bytes32 key =
      keccak256(abi.encodePacked(index, airline, flight, timestamp));
    require(
      oracleResponses[key].isOpen,
      "Flight or timestamp do not match oracle request"
    );

    oracleResponses[key].responses[statusCode].push(msg.sender);

    // Information isn't considered verified until at least MIN_RESPONSES
    // oracles respond with the *** same *** information
    emit OracleReport(airline, flight, timestamp, statusCode);
    if (oracleResponses[key].responses[statusCode].length >= MIN_RESPONSES) {
      emit FlightStatusInfo(airline, flight, timestamp, statusCode);

      // Handle flight status as appropriate
      processFlightStatus(airline, flight, timestamp, statusCode);
    }
  }

  function getFlightKey(
    address airline,
    string memory flight,
    uint256 timestamp
  ) internal pure returns (bytes32) {
    return keccak256(abi.encodePacked(airline, flight, timestamp));
  }

  // Returns array of three non-duplicating integers from 0-9
  function generateIndexes(address account) internal returns (uint8[3] memory) {
    uint8[3] memory indexes;
    indexes[0] = getRandomIndex(account);

    indexes[1] = indexes[0];
    while (indexes[1] == indexes[0]) {
      indexes[1] = getRandomIndex(account);
    }

    indexes[2] = indexes[1];
    while ((indexes[2] == indexes[0]) || (indexes[2] == indexes[1])) {
      indexes[2] = getRandomIndex(account);
    }

    return indexes;
  }

  // Returns array of three non-duplicating integers from 0-9
  function getRandomIndex(address account) internal returns (uint8) {
    uint8 maxValue = 10;

    // Pseudo random number...the incrementing nonce adds variation
    uint8 random =
      uint8(
        uint256(
          keccak256(
            abi.encodePacked(blockhash(block.number - nonce++), account)
          )
        ) % maxValue
      );

    if (nonce > 250) {
      nonce = 0; // Can only fetch blockhashes for last 256 blocks so we adapt
    }

    return random;
  }

  // endregion
}

contract FlightSuretyData {
  function isOperational() public view returns (bool);

  function setOperatingStatus(bool mode) external;

  function isAirlineRegistered(address airline) public view returns (bool);

  function isAirlineFunded(address airline) public view returns (bool);

  function isFlightRegistered(bytes32 flightKey) public view returns (bool);

  function isFlightLanded(bytes32 flightKey) public view returns (bool);

  function flightInsuredForPassenger(bytes32 flightKey, address passenger)
    public
    view
    returns (bool);

  function getRegisteredAirlineCount() public view returns (uint256);

  function getFundedAirlineCount() public view returns (uint256);

  function getRegisteredFlightCount() public view returns (uint256);

  function registerAirline(address newAirline, address registeringAirline)
    external;

  function registerFlight(
    bytes32 flightKey,
    uint256 timestamp,
    address airline,
    string memory flightNumber,
    string memory departureLocation,
    string memory arrivalLocation
  ) public payable;

  function processFlightStatus(
    address airline,
    string calldata flight,
    uint256 timestamp,
    uint8 statusCode
  ) external;

  function buy(
    bytes32 flightKey,
    address passenger,
    uint256 amount,
    uint256 payout
  ) external payable;

  function creditInsuree(bytes32 flightKey) internal;

  function pay(address payable payoutAddress) external;

  function fund(address airline, uint256 amount) external returns (bool);

  function getFlightKey(
    address airline,
    string memory flight,
    uint256 timestamp
  ) internal pure returns (bytes32);

  function fund() public payable;
}
