pragma solidity 0.5.3;

// Goals
// - Defensibility -> Kick out malicious members via forceRagequit
// - Separation of Wealth and Power -> voting / loot tokens - grant pool can't be claimed (controlled by separate contract?)
// - batch proposals -> 1 month between proposal batches, 2 week voting period, 2 week grace period
// - better spam protection -> exponential increase in deposit for same member / option to claim deposit
// - replacing members?
//   - hasn't been discussed
// - accountability to stakeholders
//   - some kind of siganlling


/**
 * @dev Wrappers over Solidity's arithmetic operations with added overflow
 * checks.
 *
 * Arithmetic operations in Solidity wrap on overflow. This can easily result
 * in bugs, because programmers usually assume that an overflow raises an
 * error, which is the standard behavior in high level programming languages.
 * `SafeMath` restores this intuition by reverting the transaction when an
 * operation overflows.
 *
 * Using this library instead of the unchecked operations eliminates an entire
 * class of bugs, so it's recommended to use it always.
 */
library SafeMath {
    /**
     * @dev Returns the addition of two unsigned integers, reverting on
     * overflow.
     *
     * Counterpart to Solidity's `+` operator.
     *
     * Requirements:
     * - Addition cannot overflow.
     */
    function add(uint256 a, uint256 b) internal pure returns (uint256) {
        uint256 c = a + b;
        require(c >= a, "SafeMath: addition overflow");

        return c;
    }

    /**
     * @dev Returns the subtraction of two unsigned integers, reverting on
     * overflow (when the result is negative).
     *
     * Counterpart to Solidity's `-` operator.
     *
     * Requirements:
     * - Subtraction cannot overflow.
     */
    function sub(uint256 a, uint256 b) internal pure returns (uint256) {
        require(b <= a, "SafeMath: subtraction overflow");
        uint256 c = a - b;

        return c;
    }

    /**
     * @dev Returns the multiplication of two unsigned integers, reverting on
     * overflow.
     *
     * Counterpart to Solidity's `*` operator.
     *
     * Requirements:
     * - Multiplication cannot overflow.
     */
    function mul(uint256 a, uint256 b) internal pure returns (uint256) {
        // Gas optimization: this is cheaper than requiring 'a' not being zero, but the
        // benefit is lost if 'b' is also tested.
        // See: https://github.com/OpenZeppelin/openzeppelin-solidity/pull/522
        if (a == 0) {
            return 0;
        }

        uint256 c = a * b;
        require(c / a == b, "SafeMath: multiplication overflow");

        return c;
    }

    /**
     * @dev Returns the integer division of two unsigned integers. Reverts on
     * division by zero. The result is rounded towards zero.
     *
     * Counterpart to Solidity's `/` operator. Note: this function uses a
     * `revert` opcode (which leaves remaining gas untouched) while Solidity
     * uses an invalid opcode to revert (consuming all remaining gas).
     *
     * Requirements:
     * - The divisor cannot be zero.
     */
    function div(uint256 a, uint256 b) internal pure returns (uint256) {
        // Solidity only automatically asserts when dividing by 0
        require(b > 0, "SafeMath: division by zero");
        uint256 c = a / b;
        // assert(a == b * c + a % b); // There is no case in which this doesn't hold

        return c;
    }

    /**
     * @dev Returns the remainder of dividing two unsigned integers. (unsigned integer modulo),
     * Reverts when dividing by zero.
     *
     * Counterpart to Solidity's `%` operator. This function uses a `revert`
     * opcode (which leaves remaining gas untouched) while Solidity uses an
     * invalid opcode to revert (consuming all remaining gas).
     *
     * Requirements:
     * - The divisor cannot be zero.
     */
    function mod(uint256 a, uint256 b) internal pure returns (uint256) {
        require(b != 0, "SafeMath: modulo by zero");
        return a % b;
    }
}

/**
 * @dev Interface of the ERC20 standard as defined in the EIP. Does not include
 * the optional functions; to access them see `ERC20Detailed`.
 */
interface IERC20 {
    /**
     * @dev Returns the amount of tokens in existence.
     */
    function totalSupply() external view returns (uint256);

    /**
     * @dev Returns the amount of tokens owned by `account`.
     */
    function balanceOf(address account) external view returns (uint256);

    /**
     * @dev Moves `amount` tokens from the caller's account to `recipient`.
     *
     * Returns a boolean value indicating whether the operation succeeded.
     *
     * Emits a `Transfer` event.
     */
    function transfer(address recipient, uint256 amount) external returns (bool);

    /**
     * @dev Returns the remaining number of tokens that `spender` will be
     * allowed to spend on behalf of `owner` through `transferFrom`. This is
     * zero by default.
     *
     * This value changes when `approve` or `transferFrom` are called.
     */
    function allowance(address owner, address spender) external view returns (uint256);

    /**
     * @dev Sets `amount` as the allowance of `spender` over the caller's tokens.
     *
     * Returns a boolean value indicating whether the operation succeeded.
     *
     * > Beware that changing an allowance with this method brings the risk
     * that someone may use both the old and the new allowance by unfortunate
     * transaction ordering. One possible solution to mitigate this race
     * condition is to first reduce the spender's allowance to 0 and set the
     * desired value afterwards:
     * https://github.com/ethereum/EIPs/issues/20#issuecomment-263524729
     *
     * Emits an `Approval` event.
     */
    function approve(address spender, uint256 amount) external returns (bool);

    /**
     * @dev Moves `amount` tokens from `sender` to `recipient` using the
     * allowance mechanism. `amount` is then deducted from the caller's
     * allowance.
     *
     * Returns a boolean value indicating whether the operation succeeded.
     *
     * Emits a `Transfer` event.
     */
    function transferFrom(address sender, address recipient, uint256 amount) external returns (bool);

    /**
     * @dev Emitted when `value` tokens are moved from one account (`from`) to
     * another (`to`).
     *
     * Note that `value` may be zero.
     */
    event Transfer(address indexed from, address indexed to, uint256 value);

    /**
     * @dev Emitted when the allowance of a `spender` for an `owner` is set by
     * a call to `approve`. `value` is the new allowance.
     */
    event Approval(address indexed owner, address indexed spender, uint256 value);
}

/**
 * @dev Contract module which provides a basic access control mechanism, where
 * there is an account (an owner) that can be granted exclusive access to
 * specific functions.
 *
 * This module is used through inheritance. It will make available the modifier
 * `onlyOwner`, which can be applied to your functions to restrict their use to
 * the owner.
 */
contract Ownable {
    address private _owner;

    event OwnershipTransferred(address indexed previousOwner, address indexed newOwner);

    /**
     * @dev Initializes the contract setting the deployer as the initial owner.
     */
    constructor () internal {
        _owner = msg.sender;
        emit OwnershipTransferred(address(0), _owner);
    }

    /**
     * @dev Returns the address of the current owner.
     */
    function owner() public view returns (address) {
        return _owner;
    }

    /**
     * @dev Throws if called by any account other than the owner.
     */
    modifier onlyOwner() {
        require(isOwner(), "Ownable: caller is not the owner");
        _;
    }

    /**
     * @dev Returns true if the caller is the current owner.
     */
    function isOwner() public view returns (bool) {
        return msg.sender == _owner;
    }

    /**
     * @dev Leaves the contract without owner. It will not be possible to call
     * `onlyOwner` functions anymore. Can only be called by the current owner.
     *
     * > Note: Renouncing ownership will leave the contract without an owner,
     * thereby removing any functionality that is only available to the owner.
     */
    function renounceOwnership() public onlyOwner {
        emit OwnershipTransferred(_owner, address(0));
        _owner = address(0);
    }

    /**
     * @dev Transfers ownership of the contract to a new account (`newOwner`).
     * Can only be called by the current owner.
     */
    function transferOwnership(address newOwner) public onlyOwner {
        _transferOwnership(newOwner);
    }

    /**
     * @dev Transfers ownership of the contract to a new account (`newOwner`).
     */
    function _transferOwnership(address newOwner) internal {
        require(newOwner != address(0), "Ownable: new owner is the zero address");
        emit OwnershipTransferred(_owner, newOwner);
        _owner = newOwner;
    }
}

contract GuildBank is Ownable {
    using SafeMath for uint256;

    IERC20 public approvedToken; // approved token contract reference

    event Withdrawal(address indexed receiver, uint256 amount);

    constructor(address approvedTokenAddress) public {
        approvedToken = IERC20(approvedTokenAddress);
    }

    function withdraw(address receiver, uint256 shares, uint256 totalShares) public onlyOwner returns (bool) {
        uint256 amount = approvedToken.balanceOf(address(this)).mul(shares).div(totalShares);
        emit Withdrawal(receiver, amount);
        return approvedToken.transfer(receiver, amount);
    }
}

contract Moloch {
    using SafeMath for uint256;

    /***************
    GLOBAL CONSTANTS
    ***************/
  uint256 public periodDuration; // default = 17280 = 4.8 hours in seconds (5 periods per day)
    uint256 public votingPeriodLength; // default = 35 periods (7 days)
    uint256 public gracePeriodLength; // default = 35 periods (7 days)
    uint256 public abortWindow; // default = 5 periods (1 day)
    uint256 public proposalDeposit; // default = 10 ETH (~$1,000 worth of ETH at contract deployment)
    uint256 public dilutionBound; // default = 3 - maximum multiplier a YES voter will be obligated to pay in case of mass ragequit
    uint256 public processingReward; // default = 0.1 - amount of ETH to give to whoever processes a proposal
    uint256 public summoningTime; // needed to determine the current period

    IERC20 public approvedToken; // approved token contract reference; default = wETH
    GuildBank public guildBank; // guild bank contract reference

    // HARD-CODED LIMITS
    // These numbers are quite arbitrary; they are small enough to avoid overflows when doing calculations
    // with periods or shares, yet big enough to not limit reasonable use cases.
    uint256 constant MAX_VOTING_PERIOD_LENGTH = 10**18; // maximum length of voting period
    uint256 constant MAX_GRACE_PERIOD_LENGTH = 10**18; // maximum length of grace period
    uint256 constant MAX_DILUTION_BOUND = 10**18; // maximum dilution bound
    uint256 constant MAX_NUMBER_OF_SHARES = 10**18; // maximum number of shares that can be minted

    /***************
    EVENTS
    ***************/
    event SubmitProposal(uint256 proposalIndex, address indexed delegateKey, address indexed memberAddress, address indexed applicant, uint256 tokenTribute, uint256 sharesRequested);
    event SubmitVote(uint256 indexed proposalIndex, address indexed delegateKey, address indexed memberAddress, uint8 uintVote);
    event ProcessProposal(uint256 indexed proposalIndex, address indexed applicant, address indexed memberAddress, uint256 tokenTribute, uint256 sharesRequested, bool didPass);
    event Ragequit(address indexed memberAddress, uint256 sharesToBurn);
    event Abort(uint256 indexed proposalIndex, address applicantAddress);
    event UpdateDelegateKey(address indexed memberAddress, address newDelegateKey);
    event SummonComplete(address indexed summoner, uint256 shares);

    /******************
    INTERNAL ACCOUNTING
    ******************/
    uint256 public totalShares = 0; // total shares across all members
    uint256 public totalSharesRequested = 0; // total shares that have been requested in unprocessed proposals

    enum Vote {
        Null, // default value, counted as abstention
        Yes,
        No
    }

    struct Member {
        address delegateKey; // the key responsible for submitting proposals and voting - defaults to member address unless updated
        uint256 shares; // the # of shares assigned to this member
        bool exists; // always true once a member has been created
        uint256 highestIndexYesVote; // highest proposal index # on which the member voted YES
    }

    struct Proposal {
        address proposer; // the member who submitted the proposal
        address applicant; // the applicant who wishes to become a member - this key will be used for withdrawals
        uint256 sharesRequested; // the # of shares the applicant is requesting
        uint256 startingPeriod; // the period in which voting can start for this proposal
        uint256 yesVotes; // the total number of YES votes for this proposal
        uint256 noVotes; // the total number of NO votes for this proposal
        bool processed; // true only if the proposal has been processed
        bool didPass; // true only if the proposal passed
        bool aborted; // true only if applicant calls "abort" fn before end of voting period
        uint256 tokenTribute; // amount of tokens offered as tribute
        string details; // proposal details - could be IPFS hash, plaintext, or JSON
        uint256 maxTotalSharesAtYesVote; // the maximum # of total shares encountered at a yes vote on this proposal
        mapping (address => Vote) votesByMember; // the votes on this proposal by each member
    }

    mapping (address => Member) public members;
    mapping (address => address) public memberAddressByDelegateKey;
    Proposal[] public proposalQueue;

    /********
    MODIFIERS
    ********/
    modifier onlyMember {
        require(members[msg.sender].shares > 0, "Moloch::onlyMember - not a member");
        _;
    }

    modifier onlyDelegate {
        require(members[memberAddressByDelegateKey[msg.sender]].shares > 0, "Moloch::onlyDelegate - not a delegate");
        _;
    }

    /********
    FUNCTIONS
    ********/
    constructor(
        address summoner,
        address _approvedToken,
        uint256 _periodDuration,
        uint256 _votingPeriodLength,
        uint256 _gracePeriodLength,
        uint256 _abortWindow,
        uint256 _proposalDeposit,
        uint256 _dilutionBound,
        uint256 _processingReward
    ) public {
        require(summoner != address(0), "Moloch::constructor - summoner cannot be 0");
        require(_approvedToken != address(0), "Moloch::constructor - _approvedToken cannot be 0");
        require(_periodDuration > 0, "Moloch::constructor - _periodDuration cannot be 0");
        require(_votingPeriodLength > 0, "Moloch::constructor - _votingPeriodLength cannot be 0");
        require(_votingPeriodLength <= MAX_VOTING_PERIOD_LENGTH, "Moloch::constructor - _votingPeriodLength exceeds limit");
        require(_gracePeriodLength <= MAX_GRACE_PERIOD_LENGTH, "Moloch::constructor - _gracePeriodLength exceeds limit");
        require(_abortWindow > 0, "Moloch::constructor - _abortWindow cannot be 0");
        require(_abortWindow <= _votingPeriodLength, "Moloch::constructor - _abortWindow must be smaller than or equal to _votingPeriodLength");
        require(_dilutionBound > 0, "Moloch::constructor - _dilutionBound cannot be 0");
        require(_dilutionBound <= MAX_DILUTION_BOUND, "Moloch::constructor - _dilutionBound exceeds limit");
        require(_proposalDeposit >= _processingReward, "Moloch::constructor - _proposalDeposit cannot be smaller than _processingReward");

        approvedToken = IERC20(_approvedToken);

        guildBank = new GuildBank(_approvedToken);

        periodDuration = _periodDuration;
        votingPeriodLength = _votingPeriodLength;
        gracePeriodLength = _gracePeriodLength;
        abortWindow = _abortWindow;
        proposalDeposit = _proposalDeposit;
        dilutionBound = _dilutionBound;
        processingReward = _processingReward;

        summoningTime = now;

        members[summoner] = Member(summoner, 1, true, 0);
        memberAddressByDelegateKey[summoner] = summoner;
        totalShares = 1;

        emit SummonComplete(summoner, 1);
    }

    /*****************
    PROPOSAL FUNCTIONS
    *****************/

    function submitProposal(
        address applicant,
        uint256 tokenTribute,
        uint256 sharesRequested,
        string memory details
    )
        public
        onlyDelegate
    {
        require(applicant != address(0), "Moloch::submitProposal - applicant cannot be 0");

        // Make sure we won't run into overflows when doing calculations with shares.
        // Note that totalShares + totalSharesRequested + sharesRequested is an upper bound
        // on the number of shares that can exist until this proposal has been processed.
        require(totalShares.add(totalSharesRequested).add(sharesRequested) <= MAX_NUMBER_OF_SHARES, "Moloch::submitProposal - too many shares requested");

        totalSharesRequested = totalSharesRequested.add(sharesRequested);

        address memberAddress = memberAddressByDelegateKey[msg.sender];

        // collect proposal deposit from proposer and store it in the Moloch until the proposal is processed
        require(approvedToken.transferFrom(msg.sender, address(this), proposalDeposit), "Moloch::submitProposal - proposal deposit token transfer failed");

        // collect tribute from applicant and store it in the Moloch until the proposal is processed
        require(approvedToken.transferFrom(applicant, address(this), tokenTribute), "Moloch::submitProposal - tribute token transfer failed");

        // compute startingPeriod for proposal
        uint256 startingPeriod = max(
            getCurrentPeriod(),
            proposalQueue.length == 0 ? 0 : proposalQueue[proposalQueue.length.sub(1)].startingPeriod
        ).add(1);

        // create proposal ...
        Proposal memory proposal = Proposal({
            proposer: memberAddress,
            applicant: applicant,
            sharesRequested: sharesRequested,
            startingPeriod: startingPeriod,
            yesVotes: 0,
            noVotes: 0,
            processed: false,
            didPass: false,
            aborted: false,
            tokenTribute: tokenTribute,
            details: details,
            maxTotalSharesAtYesVote: 0
        });

        // ... and append it to the queue
        proposalQueue.push(proposal);

        uint256 proposalIndex = proposalQueue.length.sub(1);
        emit SubmitProposal(proposalIndex, msg.sender, memberAddress, applicant, tokenTribute, sharesRequested);
    }

    function submitVote(uint256 proposalIndex, uint8 uintVote) public onlyDelegate {
        address memberAddress = memberAddressByDelegateKey[msg.sender];
        Member storage member = members[memberAddress];

        require(proposalIndex < proposalQueue.length, "Moloch::submitVote - proposal does not exist");
        Proposal storage proposal = proposalQueue[proposalIndex];

        require(uintVote < 3, "Moloch::submitVote - uintVote must be less than 3");
        Vote vote = Vote(uintVote);

        require(getCurrentPeriod() >= proposal.startingPeriod, "Moloch::submitVote - voting period has not started");
        require(!hasVotingPeriodExpired(proposal.startingPeriod), "Moloch::submitVote - proposal voting period has expired");
        require(proposal.votesByMember[memberAddress] == Vote.Null, "Moloch::submitVote - member has already voted on this proposal");
        require(vote == Vote.Yes || vote == Vote.No, "Moloch::submitVote - vote must be either Yes or No");
        require(!proposal.aborted, "Moloch::submitVote - proposal has been aborted");

        // store vote
        proposal.votesByMember[memberAddress] = vote;

        // count vote
        if (vote == Vote.Yes) {
            proposal.yesVotes = proposal.yesVotes.add(member.shares);

            // set highest index (latest) yes vote - must be processed for member to ragequit
            if (proposalIndex > member.highestIndexYesVote) {
                member.highestIndexYesVote = proposalIndex;
            }

            // set maximum of total shares encountered at a yes vote - used to bound dilution for yes voters
            if (totalShares > proposal.maxTotalSharesAtYesVote) {
                proposal.maxTotalSharesAtYesVote = totalShares;
            }

        } else if (vote == Vote.No) {
            proposal.noVotes = proposal.noVotes.add(member.shares);
        }

        emit SubmitVote(proposalIndex, msg.sender, memberAddress, uintVote);
    }

    function processProposal(uint256 proposalIndex) public {
        require(proposalIndex < proposalQueue.length, "Moloch::processProposal - proposal does not exist");
        Proposal storage proposal = proposalQueue[proposalIndex];

        require(getCurrentPeriod() >= proposal.startingPeriod.add(votingPeriodLength).add(gracePeriodLength), "Moloch::processProposal - proposal is not ready to be processed");
        require(proposal.processed == false, "Moloch::processProposal - proposal has already been processed");
        require(proposalIndex == 0 || proposalQueue[proposalIndex.sub(1)].processed, "Moloch::processProposal - previous proposal must be processed");

        proposal.processed = true;
        totalSharesRequested = totalSharesRequested.sub(proposal.sharesRequested);

        bool didPass = proposal.yesVotes > proposal.noVotes;

        // Make the proposal fail if the dilutionBound is exceeded
        if (totalShares.mul(dilutionBound) < proposal.maxTotalSharesAtYesVote) {
            didPass = false;
        }

        // PROPOSAL PASSED
        if (didPass && !proposal.aborted) {

            proposal.didPass = true;

            // if the applicant is already a member, add to their existing shares
            if (members[proposal.applicant].exists) {
                members[proposal.applicant].shares = members[proposal.applicant].shares.add(proposal.sharesRequested);

            // the applicant is a new member, create a new record for them
            } else {
                // if the applicant address is already taken by a member's delegateKey, reset it to their member address
                if (members[memberAddressByDelegateKey[proposal.applicant]].exists) {
                    address memberToOverride = memberAddressByDelegateKey[proposal.applicant];
                    memberAddressByDelegateKey[memberToOverride] = memberToOverride;
                    members[memberToOverride].delegateKey = memberToOverride;
                }

                // use applicant address as delegateKey by default
                members[proposal.applicant] = Member(proposal.applicant, proposal.sharesRequested, true, 0);
                memberAddressByDelegateKey[proposal.applicant] = proposal.applicant;
            }

            // mint new shares
            totalShares = totalShares.add(proposal.sharesRequested);

            // transfer tokens to guild bank
            require(
                approvedToken.transfer(address(guildBank), proposal.tokenTribute),
                "Moloch::processProposal - token transfer to guild bank failed"
            );

        // PROPOSAL FAILED OR ABORTED
        } else {
            // return all tokens to the applicant
            require(
                approvedToken.transfer(proposal.applicant, proposal.tokenTribute),
                "Moloch::processProposal - failing vote token transfer failed"
            );
        }

        // send msg.sender the processingReward
        require(
            approvedToken.transfer(msg.sender, processingReward),
            "Moloch::processProposal - failed to send processing reward to msg.sender"
        );

        // return deposit to proposer (subtract processing reward)
        require(
            approvedToken.transfer(proposal.proposer, proposalDeposit.sub(processingReward)),
            "Moloch::processProposal - failed to return proposal deposit to proposer"
        );

        emit ProcessProposal(
            proposalIndex,
            proposal.applicant,
            proposal.proposer,
            proposal.tokenTribute,
            proposal.sharesRequested,
            didPass
        );
    }

    function ragequit(uint256 sharesToBurn) public onlyMember {
        uint256 initialTotalShares = totalShares;

        Member storage member = members[msg.sender];

        require(member.shares >= sharesToBurn, "Moloch::ragequit - insufficient shares");

        require(canRagequit(member.highestIndexYesVote), "Moloch::ragequit - cant ragequit until highest index proposal member voted YES on is processed");

        // burn shares
        member.shares = member.shares.sub(sharesToBurn);
        totalShares = totalShares.sub(sharesToBurn);

        // instruct guildBank to transfer fair share of tokens to the ragequitter
        require(
            guildBank.withdraw(msg.sender, sharesToBurn, initialTotalShares),
            "Moloch::ragequit - withdrawal of tokens from guildBank failed"
        );

        emit Ragequit(msg.sender, sharesToBurn);
    }

    function abort(uint256 proposalIndex) public {
        require(proposalIndex < proposalQueue.length, "Moloch::abort - proposal does not exist");
        Proposal storage proposal = proposalQueue[proposalIndex];

        require(msg.sender == proposal.applicant, "Moloch::abort - msg.sender must be applicant");
        require(getCurrentPeriod() < proposal.startingPeriod.add(abortWindow), "Moloch::abort - abort window must not have passed");
        require(!proposal.aborted, "Moloch::abort - proposal must not have already been aborted");

        uint256 tokensToAbort = proposal.tokenTribute;
        proposal.tokenTribute = 0;
        proposal.aborted = true;

        // return all tokens to the applicant
        require(
            approvedToken.transfer(proposal.applicant, tokensToAbort),
            "Moloch::processProposal - failed to return tribute to applicant"
        );

        emit Abort(proposalIndex, msg.sender);
    }

    function updateDelegateKey(address newDelegateKey) public onlyMember {
        require(newDelegateKey != address(0), "Moloch::updateDelegateKey - newDelegateKey cannot be 0");

        // skip checks if member is setting the delegate key to their member address
        if (newDelegateKey != msg.sender) {
            require(!members[newDelegateKey].exists, "Moloch::updateDelegateKey - cant overwrite existing members");
            require(!members[memberAddressByDelegateKey[newDelegateKey]].exists, "Moloch::updateDelegateKey - cant overwrite existing delegate keys");
        }

        Member storage member = members[msg.sender];
        memberAddressByDelegateKey[member.delegateKey] = address(0);
        memberAddressByDelegateKey[newDelegateKey] = msg.sender;
        member.delegateKey = newDelegateKey;

        emit UpdateDelegateKey(msg.sender, newDelegateKey);
    }

    /***************
    GETTER FUNCTIONS
    ***************/

    function max(uint256 x, uint256 y) internal pure returns (uint256) {
        return x >= y ? x : y;
    }

    function getCurrentPeriod() public view returns (uint256) {
        return now.sub(summoningTime).div(periodDuration);
    }

    function getProposalQueueLength() public view returns (uint256) {
        return proposalQueue.length;
    }

    // can only ragequit if the latest proposal you voted YES on has been processed
    function canRagequit(uint256 highestIndexYesVote) public view returns (bool) {
        require(highestIndexYesVote < proposalQueue.length, "Moloch::canRagequit - proposal does not exist");
        return proposalQueue[highestIndexYesVote].processed;
    }

    function hasVotingPeriodExpired(uint256 startingPeriod) public view returns (bool) {
        return getCurrentPeriod() >= startingPeriod.add(votingPeriodLength);
    }

    function getMemberProposalVote(address memberAddress, uint256 proposalIndex) public view returns (Vote) {
        require(members[memberAddress].exists, "Moloch::getMemberProposalVote - member doesn't exist");
        require(proposalIndex < proposalQueue.length, "Moloch::getMemberProposalVote - proposal doesn't exist");
        return proposalQueue[proposalIndex].votesByMember[memberAddress];
    }
}

contract MolochPool {
    using SafeMath for uint256;

    event Sync (
        uint256 currentProposalIndex
    );

    event Deposit (
        uint256 tokenAmount,
        address donor
    );

    event Withdraw (
        uint256 sharesToBurn,
        address donor
    );

    event KeeperWithdraw (
        uint256 sharesToBurn,
        address donor,
        address keeper
    );

    event AddKeepers (
        address[] addedKeepers
    );

    event RemoveKeepers (
        address[] removedKeepers
    );

    event SharesMinted (
        uint256 sharesToMint,
        address recipient,
        uint256 totalPoolShares
    );

    event SharesBurned (
        uint256 sharesToBurn,
        address recipient,
        uint256 totalPoolShares
    );

    uint256 public totalPoolShares = 0; // the total shares outstanding of the pool
    uint256 public currentProposalIndex = 0; // the moloch proposal index that this pool has been synced to

    Moloch public moloch; // moloch contract reference
    IERC20 public approvedToken; // approved token contract reference (copied from moloch contract)

    bool locked; // prevent re-entrancy

    uint256 constant MAX_NUMBER_OF_SHARES = 10**30; // maximum number of shares that can be minted

    struct Donor {
        uint256 shares;
        mapping (address => bool) keepers;
    }

    // the amount of shares each pool shareholder has
    mapping (address => Donor) public donors;

    modifier active {
        require(totalPoolShares > 0, "MolochPool: Not active");
        _;
    }

    modifier noReentrancy() {
        require(!locked, "MolochPool: Reentrant call");
        locked = true;
        _;
        locked = false;
    }

    constructor(address _moloch) public {
        moloch = Moloch(_moloch);
        approvedToken = IERC20(moloch.approvedToken());
    }

    function activate(uint256 initialTokens, uint256 initialPoolShares) public noReentrancy {
        require(totalPoolShares == 0, "MolochPool: Already active");

        require(
            approvedToken.transferFrom(msg.sender, address(this), initialTokens),
            "MolochPool: Initial tokens transfer failed"
        );
        _mintSharesForAddress(initialPoolShares, msg.sender);
    }

    // updates Pool state based on Moloch proposal queue
    // - we only want to mint shares for grants, which are 0 tribute
    // - mints pool shares to applicants based on sharesRequested / maxTotalSharesAtYesVote
    // - use maxTotalSharesAtYesVote because:
    //   - cant read shares at the time of proposal processing (womp womp)
    //   - should be close enough if grant shares are small relative to total shares, which they should be
    //   - protects pool contributors if many Moloch members ragequit before the proposal is processed by reducing follow on funding
    //   - e.g. if 50% of Moloch shares ragequit after someone voted yes, the grant proposal would get 50% less follow-on from the pool
    function sync(uint256 toIndex) public active noReentrancy {
        require(
            toIndex <= moloch.getProposalQueueLength(),
            "MolochPool: Proposal index too high"
        );

        // declare proposal params
        address applicant;
        uint256 sharesRequested;
        bool processed;
        bool didPass;
        bool aborted;
        uint256 tokenTribute;
        uint256 maxTotalSharesAtYesVote;

        uint256 i = currentProposalIndex;

        while (i < toIndex) {

            (, applicant, sharesRequested, , , , processed, didPass, aborted, tokenTribute, , maxTotalSharesAtYesVote) = moloch.proposalQueue(i);

            if (!processed) { break; }

            // passing grant proposal, mint pool shares proportionally on behalf of the applicant
            if (!aborted && didPass && tokenTribute == 0 && sharesRequested > 0) {
                // This can't revert:
                //   1. maxTotalSharesAtYesVote > 0, otherwise nobody could have voted.
                //   2. sharesRequested is <= 10**18 (see Moloch.sol:172), and
                //      totalPoolShares <= 10**30, so multiplying them is <= 10**48 and < 2**160
                uint256 sharesToMint = totalPoolShares.mul(sharesRequested).div(maxTotalSharesAtYesVote); // for a passing proposal, maxTotalSharesAtYesVote is > 0
                _mintSharesForAddress(sharesToMint, applicant);
            }

            i++;
        }

        currentProposalIndex = i;

        emit Sync(currentProposalIndex);
    }

    // add tokens to the pool, mint new shares proportionally
    function deposit(uint256 tokenAmount) public active noReentrancy {

        uint256 sharesToMint = totalPoolShares.mul(tokenAmount).div(approvedToken.balanceOf(address(this)));

        require(
            approvedToken.transferFrom(msg.sender, address(this), tokenAmount),
            "MolochPool: Deposit transfer failed"
        );

        _mintSharesForAddress(sharesToMint, msg.sender);

        emit Deposit(
            tokenAmount,
            msg.sender
        );
    }

    // burn shares to proportionally withdraw tokens in pool
    function withdraw(uint256 sharesToBurn) public active noReentrancy {
        _withdraw(msg.sender, sharesToBurn);

        emit Withdraw(
            sharesToBurn,
            msg.sender
        );
    }

    // keeper burns shares to withdraw on behalf of the donor
    function keeperWithdraw(uint256 sharesToBurn, address recipient) public active noReentrancy {
        require(
            donors[recipient].keepers[msg.sender],
            "MolochPool: Sender is not a keeper"
        );

        _withdraw(recipient, sharesToBurn);

        emit KeeperWithdraw(
            sharesToBurn,
            recipient,
            msg.sender
        );
    }

    function addKeepers(address[] calldata newKeepers) external active noReentrancy {
        Donor storage donor = donors[msg.sender];

        for (uint256 i = 0; i < newKeepers.length; i++) {
            donor.keepers[newKeepers[i]] = true;
        }

        emit AddKeepers(newKeepers);
    }

    function removeKeepers(address[] calldata keepersToRemove) external active noReentrancy {
        Donor storage donor = donors[msg.sender];

        for (uint256 i = 0; i < keepersToRemove.length; i++) {
            donor.keepers[keepersToRemove[i]] = false;
        }

        emit RemoveKeepers(keepersToRemove);
    }

    function _mintSharesForAddress(uint256 sharesToMint, address recipient) internal {
        totalPoolShares = totalPoolShares.add(sharesToMint);
        donors[recipient].shares = donors[recipient].shares.add(sharesToMint);

        require(
            totalPoolShares <= MAX_NUMBER_OF_SHARES,
            "MolochPool: Max number of shares exceeded"
        );

        emit SharesMinted(
            sharesToMint,
            recipient,
            totalPoolShares
        );
    }

    function _withdraw(address recipient, uint256 sharesToBurn) internal {
        Donor storage donor = donors[recipient];

        require(
            donor.shares >= sharesToBurn,
            "MolochPool: Not enough shares to burn"
        );

        uint256 tokensToWithdraw = approvedToken.balanceOf(address(this)).mul(sharesToBurn).div(totalPoolShares);

        totalPoolShares = totalPoolShares.sub(sharesToBurn);
        donor.shares = donor.shares.sub(sharesToBurn);

        require(
            approvedToken.transfer(recipient, tokensToWithdraw),
            "MolochPool: Withdrawal transfer failed"
        );

        emit SharesBurned(
            sharesToBurn,
            recipient,
            totalPoolShares
        );
    }

}
