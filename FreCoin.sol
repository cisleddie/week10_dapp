// SPDX-License-Identifier: MIT
pragma solidity ^0.8.28;

import "@openzeppelin/contracts/token/ERC20/ERC20.sol";
import "@openzeppelin/contracts/access/Ownable.sol";
import "@openzeppelin/contracts/utils/Pausable.sol";

/**
 * @title FreCoin
 * @notice 주파수 생태계용 스테이블코인 — 1 FRE = 1 KRW 페그
 * @dev IKUSDC 구조 기반 경량 구현
 *      - ERC-20 기본 + Minter 위임 + Pause + Blacklist
 *      - Owner: Minter/Pauser 관리, Blacklist
 *      - Minter: mint/burn (minterAllowance 범위 내)
 *      - Pauser: pause/unpause
 */
contract FreCoin is ERC20, Ownable, Pausable {

    // ──────────────────────────────────────────
    //  Storage
    // ──────────────────────────────────────────

    address public pauser;

    mapping(address => bool)    private _minters;
    mapping(address => uint256) private _minterAllowance;
    mapping(address => bool)    private _blacklisted;

    // ──────────────────────────────────────────
    //  Events
    // ──────────────────────────────────────────

    event MinterConfigured(address indexed minter, uint256 allowance);
    event MinterRemoved(address indexed minter);
    event Mint(address indexed minter, address indexed to, uint256 amount);
    event Burn(address indexed burner, uint256 amount);
    event Blacklisted(address indexed account);
    event UnBlacklisted(address indexed account);
    event PauserChanged(address indexed newPauser);

    // ──────────────────────────────────────────
    //  Modifiers
    // ──────────────────────────────────────────

    modifier onlyMinter() {
        require(_minters[msg.sender], "FreCoin: not a minter");
        _;
    }

    modifier onlyPauser() {
        require(msg.sender == pauser, "FreCoin: not pauser");
        _;
    }

    modifier notBlacklisted(address account) {
        require(!_blacklisted[account], "FreCoin: account blacklisted");
        _;
    }

    // ──────────────────────────────────────────
    //  Constructor
    // ──────────────────────────────────────────

    /**
     * @param initialOwner  컨트랙트 오너 (프랜차이즈 또는 발행 기관)
     * @param initialPauser 초기 pauser 주소
     */
    constructor(address initialOwner, address initialPauser)
        ERC20("FreCoin", "FRE")
        Ownable(initialOwner)
    {
        pauser = initialPauser;
    }

    // ──────────────────────────────────────────
    //  ERC-20 override — blacklist + pause 적용
    // ──────────────────────────────────────────

    function transfer(address to, uint256 value)
        public override
        whenNotPaused
        notBlacklisted(msg.sender)
        notBlacklisted(to)
        returns (bool)
    {
        return super.transfer(to, value);
    }

    function transferFrom(address from, address to, uint256 value)
        public override
        whenNotPaused
        notBlacklisted(from)
        notBlacklisted(to)
        notBlacklisted(msg.sender)
        returns (bool)
    {
        return super.transferFrom(from, to, value);
    }

    function approve(address spender, uint256 value)
        public override
        whenNotPaused
        notBlacklisted(msg.sender)
        notBlacklisted(spender)
        returns (bool)
    {
        return super.approve(spender, value);
    }

    // ──────────────────────────────────────────
    //  Minter 관리 (Owner 전용)
    // ──────────────────────────────────────────

    function configureMinter(address minter, uint256 allowance_)
        external onlyOwner
    {
        _minters[minter] = true;
        _minterAllowance[minter] = allowance_;
        emit MinterConfigured(minter, allowance_);
    }

    function removeMinter(address minter) external onlyOwner {
        _minters[minter] = false;
        _minterAllowance[minter] = 0;
        emit MinterRemoved(minter);
    }

    function isMinter(address account) external view returns (bool) {
        return _minters[account];
    }

    function minterAllowance(address minter) external view returns (uint256) {
        return _minterAllowance[minter];
    }

    // ──────────────────────────────────────────
    //  Mint / Burn (Minter 전용)
    // ──────────────────────────────────────────

    function mint(address to, uint256 amount)
        external
        onlyMinter
        whenNotPaused
        notBlacklisted(to)
    {
        require(amount > 0, "FreCoin: amount must be > 0");
        require(_minterAllowance[msg.sender] >= amount, "FreCoin: minter allowance exceeded");
        _minterAllowance[msg.sender] -= amount;
        _mint(to, amount);
        emit Mint(msg.sender, to, amount);
    }

    function burn(uint256 amount)
        external
        onlyMinter
        whenNotPaused
    {
        require(amount > 0, "FreCoin: amount must be > 0");
        _burn(msg.sender, amount);
        emit Burn(msg.sender, amount);
    }

    // ──────────────────────────────────────────
    //  Blacklist (Owner 전용)
    // ──────────────────────────────────────────

    function blacklist(address account) external onlyOwner {
        _blacklisted[account] = true;
        emit Blacklisted(account);
    }

    function unBlacklist(address account) external onlyOwner {
        _blacklisted[account] = false;
        emit UnBlacklisted(account);
    }

    function isBlacklisted(address account) external view returns (bool) {
        return _blacklisted[account];
    }

    // ──────────────────────────────────────────
    //  Pause (Pauser 전용)
    // ──────────────────────────────────────────

    function pause() external onlyPauser { _pause(); }
    function unpause() external onlyPauser { _unpause(); }

    // ──────────────────────────────────────────
    //  역할 관리 (Owner 전용)
    // ──────────────────────────────────────────

    function updatePauser(address newPauser) external onlyOwner {
        pauser = newPauser;
        emit PauserChanged(newPauser);
    }

    // ──────────────────────────────────────────
    //  Decimals override — 0 소수점 (1 FRE = 1 KRW)
    // ──────────────────────────────────────────

    function decimals() public pure override returns (uint8) {
        return 0;
    }
}
