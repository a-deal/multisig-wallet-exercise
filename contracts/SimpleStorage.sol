pragma solidity ^0.5.0;

contract SimpleStorage {
    uint public storedData;

    address payable public caller;

    function set(uint x) public {
        caller = msg.sender;
        storedData = x;
    }
}
