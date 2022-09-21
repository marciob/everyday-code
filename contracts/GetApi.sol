// SPDX-License-Identifier: MIT
pragma solidity ^0.8.7;

import "@chainlink/contracts/src/v0.8/ChainlinkClient.sol";
import "@chainlink/contracts/src/v0.8/ConfirmedOwner.sol";

contract GetApi_example is ChainlinkClient, ConfirmedOwner {
    using Chainlink for Chainlink.Request;

    bool public isItOk;
    bytes32 private jobId;
    uint256 private fee;

    event RequestVolume(bytes32 indexed requestId, bool isItOk);

    constructor() ConfirmedOwner(msg.sender) {
        setChainlinkToken(0x326C977E6efc84E512bB9C30f76E30c160eD06FB);
        setChainlinkOracle(0xCC79157eb46F5624204f47AB42b3906cAA40eaB7);
        jobId = "c1c5e92880894eb6b27d3cae19670aa3";
        fee = (1 * LINK_DIVISIBILITY) / 10; // 0,1 * 10**18 (Varies by network and job)
    }

    function requestVolumeData() public returns (bytes32 requestId) {
        Chainlink.Request memory req = buildChainlinkRequest(
            jobId,
            address(this),
            this.fulfill.selector
        );

        req.add("get", "https://jsonplaceholder.typicode.com/todos/4");

        req.add("path", "completed");

        // Sends the request
        return sendChainlinkRequest(req, fee);
    }

    function fulfill(bytes32 _requestId, bool _isItOk)
        public
        recordChainlinkFulfillment(_requestId)
    {
        emit RequestVolume(_requestId, _isItOk);
        isItOk = _isItOk;
    }

    /**
     * Allow withdraw of Link tokens from the contract
     */
    function withdrawLink() public onlyOwner {
        LinkTokenInterface link = LinkTokenInterface(chainlinkTokenAddress());
        require(
            link.transfer(msg.sender, link.balanceOf(address(this))),
            "Unable to transfer"
        );
    }
}
