# 100 Day Challenge Code

The contract manages a 100 Day Code Challenge , participants deposit some specified amount to the contract at the moment of the registration, the amount is locked in the contract, able to be withdrawn at the end of the challenge, if the user has passed in the challenge.

It the participant fail to post a code on Github any day during the challenge, he/she is discounted in 25% from the initial amount deposited, that amount will be available to be divided by all winners participants at the end of the challenge. If a participant fails to post code on Github for 4 times, he/she is out of the challenge.

To prevent cheating the system or fake code, there is a function redFlagUser() that can be called by 3 to red flag a participant that has posted not legit code, if a user is red flagged 3 times, he is out of the challenge. That function is set to be called by 3 participants before it red flags a user.
