pragma solidity ^0.8.0;

import {ERC721} from "./ERC721.sol";
import {CFAv1Library} from "@superfluid-finance/ethereum-contracts/contracts/apps/CFAv1Library.sol";
import {IConstantFlowAgreementV1} from "@superfluid-finance/ethereum-contracts/contracts/interfaces/agreements/IConstantFlowAgreementV1.sol";
import {ISuperfluid, ISuperToken, ISuperAgreement, SuperAppDefinitions} from "@superfluid-finance/ethereum-contracts/contracts/interfaces/superfluid/ISuperfluid.sol";
import {SuperAppBase} from "@superfluid-finance/ethereum-contracts/contracts/apps/SuperAppBase.sol";

contract Evo is ERC721, SuperAppBase {

    using CFAv1Library for CFAv1Library.InitData;

    error NotHost();
    error NotCFAv1();
    error NotSuperToken();
    error InvalidTimestamp();
    error MaxFlowRate();

    CFAv1Library.InitData public cfaV1Lib;
    struct Info {
        uint256 timestamp;
        uint256 balance;
    }

    //id => Info(timestamp, balance)
    mapping(bytes32 => Info) internal _userInfo;

    string[5] internal evolutionURI;
    ISuperToken public evoToken;
    uint256 internal maxFlowRate;
    bytes32 constant public CFA_ID = keccak256("org.superfluid-finance.agreements.ConstantFlowAgreement.v1");

    constructor(
        string memory _name,
        string memory _symbol,
        address _superToken,
        address _host,
        uint256 _maxFlowRate
    ) ERC721(_name, _symbol) {

        //in this example all NFT will share the same art.
        evolutionURI[0] = "QmdcjBYuAZiW4Vm8TR6AEE6Ajt9LVLT5WvLL3Rqt5f46fC";
        evolutionURI[1] = "QmSV6CR78bWSsuNe2ZNXoCAZcbUDqZ5wZW1kDLLZRVjDZJ";
        evolutionURI[2] = "QmdAUKamZeBwkktWt8sD3Ru9vKp4SmqdVyGGdSNSwfGfXP";
        evoToken = ISuperToken(_superToken);
        maxFlowRate = _maxFlowRate;
        cfaV1Lib = CFAv1Library.InitData(
            ISuperfluid(_host),
            IConstantFlowAgreementV1(
                address(ISuperfluid(_host).getAgreementClass(CFA_ID))
            )
        );

        uint256 configWord =
            SuperAppDefinitions.APP_LEVEL_FINAL |
            SuperAppDefinitions.BEFORE_AGREEMENT_CREATED_NOOP;

        ISuperfluid(_host).registerApp(configWord);
    }

    // get URI based on NFT evolution state
    function tokenURI(uint256 id) public view override returns (string memory) {
        if(!isTokenValid(id)) return "";
        uint256 paragon = _getParagonLevel(_getBalanceById(id));
        return string(abi.encodePacked("https://ipfs.io/ipfs/", evolutionURI[paragon - 1]));
    }

    function getParagon(uint256 id) public view returns(uint256) {
        return _getParagonLevel(_getBalanceById(id));
    }

    function isTokenValid(uint256 id) public view returns (bool) {
        return _userInfo[bytes32(id)].timestamp > 0 || _userInfo[bytes32(id)].balance > 0;
    }

    function afterAgreementCreated(
        ISuperToken superToken,
        address agreementClass,
        bytes32 agreementId,
        bytes calldata agreementData,
        bytes calldata /*cbdata*/,
        bytes calldata ctx
    )
    external override
    onlyHost
    onlyExpected(superToken, agreementClass)
    returns (bytes memory newCtx)
    {
        newCtx = ctx;
        int96 flowRate = _getFlowRateByID(agreementId);
        if(_getMaxFlowRate(uint256(agreementId)) < uint256(uint96(flowRate))) revert MaxFlowRate();
        _userInfo[agreementId].timestamp = block.timestamp;
        if(_userInfo[agreementId].balance == 0) {
            //mint new NFT
            (address sender,) = abi.decode(agreementData, (address, address));
            _mint(sender, uint256(agreementId));
        }
    }

    function beforeAgreementUpdated(
        ISuperToken /*superToken*/,
        address /*agreementClass*/,
        bytes32 agreementId,
        bytes calldata /*agreementData*/,
        bytes calldata /*ctx*/
    )
    external override
    view
    returns (bytes memory cbdata)
    {
        return abi.encode(_getFlowRateByID(agreementId));
    }

    function afterAgreementUpdated(
        ISuperToken superToken,
        address agreementClass,
        bytes32 agreementId,
        bytes calldata agreementData,
        bytes calldata cbdata,
        bytes calldata ctx
    )
    external override
    onlyHost
    onlyExpected(superToken, agreementClass)
    returns (bytes memory newCtx)
    {
        int96 oldFlowRate = abi.decode(cbdata, (int96));
        if(_getMaxFlowRate(uint256(agreementId)) > maxFlowRate) revert MaxFlowRate();
        _settleUserAmount(agreementId, oldFlowRate);
        _userInfo[agreementId].timestamp = block.timestamp;
        return ctx;
    }

    function beforeAgreementTerminated(
        ISuperToken superToken,
        address agreementClass,
        bytes32 agreementId,
        bytes calldata /*agreementData*/,
        bytes calldata /*ctx*/
    )
    external
    view
    override
    onlyHost
    returns (bytes memory cbdata)
    {
        if (!_isSameToken(superToken) || !_isCFAv1(agreementClass) ) {
            return "";
        }
        return abi.encode(_getFlowRateByID(agreementId));
    }

    function afterAgreementTerminated(
        ISuperToken superToken,
        address agreementClass,
        bytes32 agreementId,
        bytes calldata agreementData,
        bytes calldata cbdata,
        bytes calldata ctx
    )
    external override
    onlyHost
    returns (bytes memory newCtx)
    {
        if (!_isSameToken(superToken) || !_isCFAv1(agreementClass)) {
            return ctx;
        }
        int96 oldFlowRate = abi.decode(cbdata, (int96));
        _settleUserAmount(agreementId, oldFlowRate);
        return ctx;
    }

    /**************************************************************************
    * Internal helper functions
    *************************************************************************/

    // depending on your level, maxFlowRate changes
    function _getMaxFlowRate(uint256 id) internal view returns(uint256) {
        uint256 paragon = _getParagonLevel(_getBalanceById(id));
        return maxFlowRate * paragon;
    }

    //get full balance
    function _getBalanceById(uint256 id) internal view returns(uint256) {
        bytes32 bId = bytes32(id);
        int96 flowRate = _getFlowRateByID(bId);
        return _userInfo[bId].balance + (block.timestamp - _userInfo[bId].timestamp) * uint256(uint96(flowRate));
    }

    //get level based on amount
    function _getParagonLevel(uint256 amount) internal pure returns(uint256) {
        // level table
       if (amount > 2 ether) {
            return 3;
        } else if (amount > 1 ether) {
            return 2;
        } else {
            return 1;
        }
    }

    //calculate diff between last update and now. convert to balance and reset timestamp.
    //@notice: the timestamp is only reset to zero.
    function _settleUserAmount(bytes32 id, int96 oldFlowRate) internal {
        if(_userInfo[id].timestamp == 0) revert InvalidTimestamp();
        uint256 timeDiff = block.timestamp - _userInfo[id].timestamp;
        delete _userInfo[id].timestamp;
        _userInfo[id].balance += (timeDiff * uint256(uint96(oldFlowRate)));
    }

    function _getFlowRateByID(bytes32 agreementId) internal view returns(int96 flowRate) {
        (,flowRate , ,) = cfaV1Lib.cfa.getFlowByID(evoToken, agreementId);
    }

    function _isSameToken(ISuperToken superToken) private view returns (bool) {
        return address(superToken) == address(evoToken);
    }

    function _isCFAv1(address agreementClass) private view returns (bool) {
        return ISuperAgreement(agreementClass).agreementType() == CFA_ID;
    }

    modifier onlyHost() {
        if(msg.sender != address(cfaV1Lib.host)) revert NotHost();
        _;
    }

    modifier onlyExpected(ISuperToken superToken, address agreementClass) {
        if(!_isSameToken(superToken)) revert NotSuperToken();
        if(!_isCFAv1(agreementClass)) revert NotCFAv1();
        _;
    }
}
