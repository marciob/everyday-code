// SPDX-License-Identifier: MIT
pragma solidity ^0.8.7;

import "@openzeppelin/contracts/access/Ownable.sol";
import "@openzeppelin/contracts/security/ReentrancyGuard.sol";

interface IGetApi {
    function getData(address _address) external returns (uint, uint);
}

contract EverydayCode is Ownable, ReentrancyGuard {
    uint public userID;
    uint public requiredDeposit = 200;
    uint public cutFee = requiredDeposit / 4;
    uint public day = 86400;
    uint public challengeDeadline = 100 * day;
    bool public isRegistryOpen = true;
    uint public contractBalance;
    uint public activedUsers;

    event userEntered(string message, string github, address indexed);
    event challengeStarted(string message);
    event userFailedGithub(string message, address indexed user, uint day);
    event userGameOverByGithub(string message, address indexed user, uint day);
    event userGameOverByFlags(string message, address indexed user);
    event userHasBeenFlagged(
        string message,
        address indexed user,
        uint flagsCounter
    );
    event userWithdraw(string message, address indexed user);

    constructor() {}

    /*
     * @param    githubUsername, self-explained
     * @param    isActive, it's turned of when a participant finishes a cycle,
     * either because he/she ended winning the cycle or failed it
     * @param    userAddress, self-explained
     * @param    redFlag, it's used to red flag the user,
     * if the user is red flagged 3 times, he/she gets inactivated.
     * @param    balance, it stores the user balance
     */
    struct User {
        string githubUsername;
        bool isActive;
        address userAddress;
        uint redFlag;
        uint balance;
    }

    User[] public users;

    mapping(address => uint) public usersArr;

    mapping(address => uint) public userHasNotUpdatedGithub; //timestamp for the latest flag that a user received
    mapping(address => uint) public latestGithubAbsence; //latest day that the user was absent in github
    mapping(address => uint) public dayNotUpdated; //days that the user has not updated the github
    mapping(address => mapping(address => uint)) public latestPreFlag; //it maps the when an address has flagged a user
    mapping(address => uint) public preFlagCounter; //it counts how many preRedFlag a user has received
    mapping(address => uint) public latestFlagged; //timestamp for the latest flag that a user received

    modifier onlyUser() {
        require(usersArr[msg.sender] > 0, "Msg.sender isn't a participant");
        _;
    }

    /*
     * Users enter in the challenge by calling this function and passing their github username,
     * later that username will be used to track their activity in a separeted contract for that,
     * the deposited amount is specified in 200 Matic,
     * the challenge starts when startChallenge() is called, when it happens participantRegistry() is closed for new registrants
     */
    function participantRegistry(string memory _githubUsername) public payable {
        require(isRegistryOpen == true);
        require(usersArr[msg.sender] == 0, "user already registred");
        require(msg.value == 200 ether, "required deposit of 200 Matic");

        userID++;
        activedUsers++;

        User memory user;

        user.githubUsername = _githubUsername;
        user.isActive = true;
        user.balance = msg.value;
        user.userAddress = msg.sender;
        usersArr[msg.sender] = userID;

        users.push(user);

        emit userEntered("User has enteredd ", _githubUsername, msg.sender);
    }

    /*
     * it opens the challenge,
     * setting the challenge deadline to + 100 days,
     * setting isRegistryOpen to false and
     * blocking new registrants on participantRegistry();
     */
    function startChallenge() external onlyOwner {
        challengeDeadline += block.timestamp;
        isRegistryOpen = false;
        emit challengeStarted("Challenge has started");
    }

    /*
     * if for any reason necessary, it allows to manage the registrations opening/closing
     */
    function manageChallenge(bool _set) external onlyOwner {
        isRegistryOpen = _set;
    }

    /*
     * this function will be called automatically by a Chainlink Keepers contract at 0h01 of each day of the challenge,
     * to do that, it calls a contract that returns two information:
     * first - if the user has failed to post on github,
     * second - if so, the day that he/she has failed,
     * if failed to post on github, a fee is discounted from their balance equivalent to 25% from initial deposited amount
     */
    function isGithubUpdated(address _user, address _apiContractAddress)
        public
        returns (uint, uint)
    {
        User storage user = users[usersArr[_user]];

        require(
            user.isActive == true,
            "user needs to be active to check their github activity"
        );

        //calls the contract that returns the data if the user has coded in github in the previous day,
        //and also returns which day it refers, in a range of 1 to 100 days,
        //those returned are stored in the respective variables, result and challengeDay
        (uint result, uint challengeDay) = IGetApi(_apiContractAddress).getData(
            _user
        );

        if (result == 1) {
            //1 means false in this case, meaning that user hasn't posted on github in the previous day

            if (latestGithubAbsence[_user] != challengeDay) {
                //it requires that the specified day hasn't been handled yet
                latestGithubAbsence[_user] = challengeDay;

                user.balance -= cutFee;
                contractBalance += cutFee;
                userHasNotUpdatedGithub[_user] += 1;

                if (userHasNotUpdatedGithub[_user] > 3) {
                    //if more than 3 days failling to post on github, user is kicked out the system
                    user.isActive = false;
                    contractBalance += user.balance;
                    user.balance = 0;
                    activedUsers -= 1;

                    emit userGameOverByGithub(
                        "User is kicked out by reaching github absense limit",
                        _user,
                        challengeDay
                    );

                    return (result, challengeDay);
                }
                emit userFailedGithub(
                    "User hasn't updated Github",
                    _user,
                    challengeDay
                );
            }
        }
        return (result, challengeDay);
    }

    /*
     * Red Flag is used when a user try to cheat the system with a fake or not reliable github update.
     * To red flag an user it's necessary an action of 3 participants within 24h to confirm the red flag.
     * If a user is red flagged 3 times, he/she is kicked out the challenge.
     */
    function redFlagUser(address _user) external onlyUser {
        //it checks if msg.sender has flagged the same user within the latest 24h
        require(
            (latestPreFlag[msg.sender][_user] + day) < block.timestamp,
            "msg.sender already has flagged this user within the latest 24h"
        );
        //it checks if user has been flagged within the latest 24h
        require(
            (latestFlagged[_user] + day) < block.timestamp,
            "user already has been flaggged within the latest 24h"
        );

        //it maps when the msg.sender has flagged this user
        //so it resets the previous timestamp and replaces for the current one
        latestPreFlag[msg.sender][_user] = block.timestamp;

        preFlagCounter[_user] += 1;

        if (preFlagCounter[_user] > 2) {
            User storage user = users[usersArr[_user]];
            contractBalance += user.balance;
            user.balance = 0;

            user.isActive = false;

            preFlagCounter[_user] = 0;
            latestFlagged[_user] = block.timestamp;
            activedUsers -= 1;

            emit userGameOverByFlags(
                "User reached a red flag limit and is out of the system",
                _user
            );

            return;
        }
        emit userHasBeenFlagged(
            "User has received a red flag",
            _user,
            preFlagCounter[_user]
        );
    }

    /*
     * withdraws can be made only after the challenge deadline has passed,
     * it adds to the user balance, his/her proportional amount from the money descounted
     * from the users that have failed
     */
    function userWithdrawAll() external onlyUser nonReentrant {
        require(
            block.timestamp > challengeDeadline,
            "The challenge deadline hasn't passed yet"
        );
        uint _userID = usersArr[msg.sender];

        User storage user = users[_userID];

        require(user.balance > 0, "user has no balance");

        (bool success, ) = msg.sender.call{
            value: user.balance + rewardsPerUser()
        }("");
        require(success, "Transfer failed.");

        user.balance = 0;

        emit userWithdraw("User has withdrawn", msg.sender);
    }

    /*
     * it calculates the amount of rewards that active users should receive at the end of the challenge,
     * it does that calculating how much there is the contract (descounted from users that has failed),
     * and divide it among the number of active users
     */
    function rewardsPerUser() public view returns (uint) {
        uint result = contractBalance / activedUsers;
        return result;
    }
}
