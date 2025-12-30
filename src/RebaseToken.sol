//SPDX-License-Identifier: MIT

pragma solidity ^0.8.24;

import {ERC20} from "@openzeppelin/contracts/token/ERC20/ERC20.sol";
import {Ownable} from "@openzeppelin/contracts/access/Ownable.sol";
import {AccessControl} from "@openzeppelin/contracts/access/AccessControl.sol";

/**
 * @title RebaseToken
 * @author DecentralizedGlasses(Sivaji)
 * @notice this is a going to be a cross-chain rebase token that incentvises users to deposit into a vault and gains interestin rewards
 * @notice the interest rate in the samrt contract can only decrease
 * @notice each user will have their own interest rate that is the global interest rate at the time of depositing
 */
contract RebaseToken is ERC20, Ownable, AccessControl {
    ///////////////////////
    ////// ERRORS ////////
    //////////////////////
    error RebaseToken__InterestRateCanOnlyDecrease(uint256 oldInterestRate, uint256 newInterestRate);

    //////////////////////////
    ///// STATE VARIABLES ////
    //////////////////////////
    uint256 private constant PRECISION_FACTOR = 1e18;
    bytes32 private constant MINT_AND_BURN_ROLE = keccak256("MINT_AND_BURN_ROLE");
    mapping(address => uint256) private s_userInterestRate; // mapping to store the specific interest rate "locked in" for each user when they first interact (e.g., mint tokens).
    mapping(address => uint256) private s_userLastUpdatedTimeStamp; //mapping to store the timestamp of the last time each user's balance effectively accrued interest or was updated.

    uint256 private s_interestRate = (5 * PRECISION_FACTOR) / 1e8; //due to precision we're doing this as 5e10 aka 5% interest rate

    //////////////////
    ///// EVENTS ////
    /////////////////
    event InterestRateSet(uint256 newInterestRate);

    //////////////////////
    //// CONSTRUCTOR ////
    /////////////////////

    constructor() Ownable(msg.sender) ERC20("RebaseToken", "RBT") {}

    // constructor() ERC20("Rebase Token", "RBT") Ownable(msg.sender) {}

    /////////////////////
    ///// FUNCTIONS /////
    /////////////////////

    function grantMintAndBurnRole(address _account) external onlyOwner {
        _grantRole(MINT_AND_BURN_ROLE, _account);
    }

    /**
     * @notice Set the interest rate in the contract
     * @param _newInterestRate , the new interest rate to set
     * @dev The interest rate can only decrease
     */

    function setInterestRate(uint256 _newInterestRate) external onlyOwner {
        //set the interest rate
        if (_newInterestRate >= s_interestRate) {
            revert RebaseToken__InterestRateCanOnlyDecrease(s_interestRate, _newInterestRate);
        }
        s_interestRate = _newInterestRate;
        emit InterestRateSet(_newInterestRate);
    }

    /**
     * @notice Fetching the principle balance of user from an external call
     * @notice This gets the amount of tokens that are minted to the user, not including any interest that has accured since the last time the user interacted with the protocol.
     * @param _user -> address of user who's balance needs to fetch
     * @return Returns the balance of user by calling from parent contract
     */
    function principleBalanceOf(address _user) external view returns (uint256) {
        return super.balanceOf(_user);
    }

    /**
     * @notice Mint the user tokens when they deposit into the vault
     * @param _to -> the user address to mint the tokens to
     * @param _amount -> the amount of tokens to mint
     */

    function mint(address _to, uint256 _amount, uint256 _userInterestRate) public onlyRole(MINT_AND_BURN_ROLE) {
        // Step 1: Mint any existing accrued interest for the user
        _mintAccuredInterest(_to); // this will mint that has accured since the last time taken action like minting, burning,

        // Step 2: Update the user's interest rate for future calculations if necessary
        // This assumes s_interestRate is the current global interest rate.
        // If the user already has a deposit, their rate might be updated.
        s_userInterestRate[_to] = _userInterestRate;

        // Step 3: Mint the newly deposited amount
        _mint(_to, _amount);
    }

    /**
     *@notice Burn the user tokens when they want to redeem
     *@param _from -> user address to burn the tokens from
     *@param _amount -> amount of tokens to burn
     */

    function burn(address _from, uint256 _amount) public onlyRole(MINT_AND_BURN_ROLE) {
        // if the user want to redeem his total balance we'll burn his total balance including interest
        // if (_amount == type(uint256).max) {
        //     _amount = balanceOf(_from);
        // }
        _mintAccuredInterest(_from);
        _burn(_from, _amount);
    }

    /**
     * @notice calculate the interest of the user including the interest that has accumulated since the last time balance was updated.
     * (principle balance) + some interest that has accured
     * @param _user -> address of user which balance is going to fetch
     * @return The balance of user including the interest rate that has accumulated since the last update
     */

    function balanceOf(address _user) public view override returns (uint256) {
        // get the current principal balance of the user(the number of tokens that have actually)
        // multiply the principle balance by the interest that has accumulated in the time since the balance was updated
        uint256 currentPrincipalBalance = super.balanceOf(_user);
        if (currentPrincipalBalance == 0) {
            return 0;
        }
        return (currentPrincipalBalance * _calculateUserAccumulatedInterestSinceLastUpdate(_user)) / PRECISION_FACTOR; // this "super" keyword tell that find this function in the contract that we're inheriting and call that
    }

    /**
     * @notice Transfer tokens from one to another
     * @param _recipient -> the receipient address who is receiving tokens
     * @param _amount -> amount of tokens user transferring
     * @return True is the transfer was successful
     */

    function transfer(address _recipient, uint256 _amount) public override returns (bool) {
        if (_amount == type(uint256).max) {
            _amount = balanceOf(msg.sender);
        }
        // Before making any transaction we need to make sure that is there any interest accured
        _mintAccuredInterest(msg.sender); //msg.sender is our from address
        _mintAccuredInterest(_recipient); //same as to recipient

        // If they not yet deposited any tokens previously then we inherit the interest rate
        if (balanceOf(_recipient) == 0) {
            s_userInterestRate[_recipient] = s_userInterestRate[msg.sender];
        }

        // finally we're going to call the transfer in parent contract to transfer the amount to recipient
        return super.transfer(_recipient, _amount);
    }

    /**
     * @notice Transfer tokens from sender to recipient
     * @param _sender -> sender address who is sending tokens
     * @param _recipient -> the receipient address who is receiving tokens
     * @param _amount -> amount of tokens user transferring
     * @return True is the transfer was successful
     */
    function transferFrom(address _sender, address _recipient, uint256 _amount) public override returns (bool) {
        if (_amount == type(uint256).max) {
            _amount = balanceOf(_sender);
        }
        _mintAccuredInterest(_sender);
        _mintAccuredInterest(_recipient);

        if (balanceOf(_recipient) == 0) {
            // if the recipient balance is zero(means doesn't deposit anything) then setting the interest rate as same as sender
            s_userInterestRate[_recipient] = s_userInterestRate[_sender]; //chosen but we can chose anything
        }

        return super.transferFrom(_sender, _recipient, _amount);
    }

    /**
     * @notice Calculate the interest that has accumulated since the last udpate
     * @param _user -> The user to calculate the interest accumulated for
     * @return linearInterest The interest accumulated since the last update
     */

    function _calculateUserAccumulatedInterestSinceLastUpdate(address _user)
        internal
        view
        returns (uint256 linearInterest)
    {
        // interest accumulated since last update
        // this is going to be linear growth with time
        // 1. calculate the time since last update
        // 2. calculate the interest that has accumulated since the last update (linear growth)
        // (principal amount(1 + (user interest rate* time elapsed));
        // tokens: 20
        // interest rate: 0.5 tokens per second
        // time elapsed: 2 sec
        // 10 + 10*0.5*2
        uint256 timeElapsed = block.timestamp - s_userLastUpdatedTimeStamp[_user];
        linearInterest = PRECISION_FACTOR + (s_userInterestRate[_user] * timeElapsed);
        return linearInterest;
    }

    /**
     * @notice the below function follows CEI pattern
     * (1), (2), (3), does the checks and the following lines does EFFECTS and following lines does INTERACTIONS by minting accured interest
     * @notice Mint the accured interest since the last time the protocol updated to the user
     * @param _user address as parameter
     */
    function _mintAccuredInterest(address _user) internal {
        // (1) find the current balance of rebase tokens that have been minted to the user -> principal balance
        uint256 previousPrincipleBalance = super.balanceOf(_user); //from inherited contract
        // (2) calculate the current balance including any interest -> balanceOf
        uint256 currentBalance = balanceOf(_user); //from this contract
        // (3) calculate the number of tokens that need to be minted to the user -> (2) - (1)
        uint256 balanceIncrease = currentBalance - previousPrincipleBalance;

        // call _mint to mint tokens to the user
        if (balanceIncrease > 0) { //this is for optimization



            _mint(_user, balanceIncrease);
        }
        // set the users last updated time stamp
        s_userLastUpdatedTimeStamp[_user] = block.timestamp;
    }

    //////////////////////////
    //// GETTER FUNCTIONS ////
    //////////////////////////

    /**
     * @notice Get the interest Rate , that is currently set for the contract, any future depositos will receive this interest rate
     * @return The interest rate of the user
     */
    function getInterestRate() external view returns (uint256) {
        return s_interestRate;
    }

    /**
     * @notice Get the interest Rate for the user
     * @param _user the user to get the interest rate
     * @return The interest rate of the user
     */
    function getUserInterestRate(address _user) external view returns (uint256) {
        return s_userInterestRate[_user];
    }
}
