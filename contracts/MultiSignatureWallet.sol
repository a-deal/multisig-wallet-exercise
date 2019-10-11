pragma solidity ^0.5.0;

import "@openzeppelin/contracts/math/SafeMath.sol";
contract MultiSignatureWallet {
    
    using SafeMath for uint;
    
    address[] owners;
    uint public required;
    uint public transactionCount;
    mapping (address => bool) isOwner;
    mapping (uint => Transaction) transactions;
    mapping (uint => mapping (address => bool)) confirmations;

    struct Transaction {
	  bool executed;
      address destination;
      uint value;
      bytes data;
    }
    
    /// @dev Events are recommended for any changes to state variables
    event Submission(uint indexed transactionId);
    event Confirmation(uint indexed transactionId, address indexed sender);
    event Execution(uint indexed transactionId);
    event ExecutionFailure(uint indexed transactionId);

    /// @dev Fallback function, which accepts ether when sent to contract
    /// @dev This can be left empty as fallback functions do not accept any arguments. There may be data in the message accessible via msg.data. 
    ///      An event may be emitted for visibility when this does takes place. For more: https://tinyurl.com/y266xadx.
    function() external payable {}
    
    /*
    * Modifiers
    */
    /// @dev Ensure contract is initialized with valid multisignature specifics
    /// @param _ownerCount Number of owners for a given instance of this wallet
    /// @param _required Number of confirmations required before a transaction can be executed
    modifier validRequirements(uint _ownerCount, uint _required) {
        // Check to see that # of required signatures is not greater than # of owners
        // Check to see that at least on account is in the owner's array
        // Check to see that at least 1 required signature is needed for executing a transaction
        if (_ownerCount == 0 || _required == 0 || _required > _ownerCount) {
          revert('Invalid configuration for Multisig Wallet');
        }
        _;
    }

    /*
     * Public functions
     */
    /// @dev Contract constructor sets initial owners and required number of confirmations.
    /// @param _owners List of initial owners.
    /// @param _required Number of required confirmations.
    constructor(address[] memory _owners, uint _required) public validRequirements(_owners.length, _required) {
        owners = _owners;
        required = _required;
        
        for (uint i = 0; i < _owners.length; i++) {
            isOwner[_owners[i]] = true;
        }
    }

    function getOwners() public view returns (address[] memory) {
        return owners;
    }

    /// @dev Allows an owner to submit and confirm a transaction.
    /// @param _destination Transaction target address.
    /// @param _value Transaction ether value.
    /// @param _data Transaction data payload.
    /// @return Returns transaction ID.
    function submitTransaction(address _destination, uint _value, bytes memory _data) public returns (uint transactionId) {
        require(isOwner[msg.sender]);
        transactionId = addTransaction(_destination, _value, _data);
        confirmTransaction(transactionId);
    }

    /// @dev Allows an owner to confirm a transaction.
    /// @param _transactionId Transaction ID.
    function confirmTransaction(uint _transactionId) public {
        require(isOwner[msg.sender]);
        require(transactions[_transactionId].destination != address(0));
        // Owner hasn't already confirmed
        require(confirmations[_transactionId][msg.sender] == false);
        confirmations[_transactionId][msg.sender] = true;
        emit Confirmation(_transactionId, msg.sender);
        executeTransaction(_transactionId);
    }

    /// @dev Allows an owner to revoke a confirmation for a transaction.
    /// @param transactionId Transaction ID.
    function revokeConfirmation(uint transactionId) public {}

    /// @dev Allows anyone to execute a confirmed transaction.
    /// @param _transactionId Transaction ID.
    function executeTransaction(uint _transactionId) public {
        require(transactions[_transactionId].executed == false);
        // Check to see if confirmation count is equal to or higher than required amount
        if(isConfirmed(_transactionId)) {
            Transaction storage t = transactions[_transactionId];
            (bool success, ) = t.destination.call.value(t.value)(t.data);
            if (success) {
                t.executed = true;
                emit Execution(_transactionId);
            } else {
                emit ExecutionFailure(_transactionId);
            }
        }
    }

		/*
		 * (Possible) Helper Functions
		 */
    /// @dev Returns the confirmation status of a transaction.
    /// @param _transactionId Transaction ID.
    /// @return Confirmation status.
    function isConfirmed(uint _transactionId) internal view returns (bool) {
        uint confirmationCount = 0;
        for (uint i = 0; i < owners.length; i++) {
            if (confirmations[_transactionId][owners[i]] == true) {
                confirmationCount = confirmationCount.add(1);
            }
            if (confirmationCount == required) {
                return true;
            }
        }
    }

    /// @dev Adds a new transaction to the transaction mapping, if transaction does not exist yet.
    /// @param _destination Transaction target address.
    /// @param _value Transaction ether value.
    /// @param _data Transaction data payload.
    /// @return Returns transaction ID.
    function addTransaction(address _destination, uint _value, bytes memory _data) internal returns (uint transactionId) {
        transactionId = transactionCount;
        transactions[transactionId] = Transaction({ destination: _destination, value: _value, data: _data, executed: false });
        transactionCount = transactionCount.add(1);
        emit Submission(transactionId);
    }
}
