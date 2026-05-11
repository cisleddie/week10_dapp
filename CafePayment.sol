// SPDX-License-Identifier: MIT
pragma solidity ^0.8.28;

import "@openzeppelin/contracts/access/Ownable.sol";
import "@openzeppelin/contracts/utils/ReentrancyGuard.sol";
import "@openzeppelin/contracts/token/ERC20/IERC20.sol";

/**
 * @title CafePayment
 * @notice FreCoin(FRE) 기반 카페 결제 컨트랙트
 * @dev ICafePayment 인터페이스 구현
 *      - 방식 A: approve → pay() (일반 ERC-20)
 *      - Owner(프랜차이즈): 화이트리스트·수수료·머천트 관리
 *      - Merchant(카페 오너): 결제금액(수수료 제외) 수취
 */
contract CafePayment is Ownable, ReentrancyGuard {

    // ──────────────────────────────────────────
    //  Constants
    // ──────────────────────────────────────────

    uint256 public constant FEE_DENOMINATOR = 10_000;
    uint256 public constant MAX_FEE_RATE    = 1_000; // 최대 10%

    // ──────────────────────────────────────────
    //  Storage
    // ──────────────────────────────────────────

    address public merchant;
    uint256 public feeRate; // basis points (e.g. 200 = 2%)

    mapping(address => bool)    public whitelistedTokens;
    mapping(address => uint256) public collectedFees; // token → 누적 수수료

    // ──────────────────────────────────────────
    //  Events
    // ──────────────────────────────────────────

    event Paid(
        address indexed payer,
        address indexed token,
        uint256 amount,
        uint256 fee,
        string  method,
        uint256 timestamp
    );
    event TokenWhitelisted(address indexed token);
    event TokenRemovedFromWhitelist(address indexed token);
    event FeeRateUpdated(uint256 oldRate, uint256 newRate);
    event MerchantUpdated(address oldMerchant, address newMerchant);
    event Withdrawn(address indexed token, uint256 amount);

    // ──────────────────────────────────────────
    //  Constructor
    // ──────────────────────────────────────────

    /**
     * @param initialOwner    프랜차이즈 주소
     * @param initialMerchant 카페 오너 주소
     * @param initialFeeRate  초기 수수료율 (basis points)
     * @param freToken        FreCoin 컨트랙트 주소 (자동 화이트리스트 등록)
     */
    constructor(
        address initialOwner,
        address initialMerchant,
        uint256 initialFeeRate,
        address freToken
    ) Ownable(initialOwner) {
        require(initialMerchant != address(0), "CafePayment: zero merchant");
        require(initialFeeRate <= MAX_FEE_RATE, "CafePayment: fee too high");

        merchant = initialMerchant;
        feeRate  = initialFeeRate;

        // FreCoin 자동 화이트리스트
        whitelistedTokens[freToken] = true;
        emit TokenWhitelisted(freToken);
    }

    // ──────────────────────────────────────────
    //  결제 — 방식 A (approve + pay)
    // ──────────────────────────────────────────

    /**
     * @notice 사전 approve 후 결제
     * @param token  결제 토큰 주소 (화이트리스트에 있어야 함)
     * @param amount 결제 금액 (최소 단위)
     */
    function pay(address token, uint256 amount) external nonReentrant {
        _processPayment(token, amount, msg.sender, "approve");
    }

    // ──────────────────────────────────────────
    //  내부 결제 처리
    // ──────────────────────────────────────────

    function _processPayment(
        address token,
        uint256 amount,
        address payer,
        string memory method
    ) internal {
        require(whitelistedTokens[token], "CafePayment: token not whitelisted");
        require(amount > 0,               "CafePayment: amount must be > 0");
        require(merchant != address(0),   "CafePayment: merchant not set");

        // 수수료 계산
        uint256 fee            = (amount * feeRate) / FEE_DENOMINATOR;
        uint256 merchantAmount = amount - fee;

        IERC20 erc20 = IERC20(token);

        // payer → merchant (수수료 제외 금액)
        require(
            erc20.transferFrom(payer, merchant, merchantAmount),
            "CafePayment: merchant transfer failed"
        );

        // payer → contract (수수료)
        if (fee > 0) {
            require(
                erc20.transferFrom(payer, address(this), fee),
                "CafePayment: fee transfer failed"
            );
            collectedFees[token] += fee;
        }

        emit Paid(payer, token, amount, fee, method, block.timestamp);
    }

    // ──────────────────────────────────────────
    //  화이트리스트 관리 (Owner 전용)
    // ──────────────────────────────────────────

    function addWhitelistedToken(address token) external onlyOwner {
        require(token != address(0), "CafePayment: zero address");
        whitelistedTokens[token] = true;
        emit TokenWhitelisted(token);
    }

    function removeWhitelistedToken(address token) external onlyOwner {
        whitelistedTokens[token] = false;
        emit TokenRemovedFromWhitelist(token);
    }

    // ──────────────────────────────────────────
    //  Merchant 관리 (Owner 전용)
    // ──────────────────────────────────────────

    function setMerchant(address newMerchant) external onlyOwner {
        require(newMerchant != address(0), "CafePayment: zero address");
        emit MerchantUpdated(merchant, newMerchant);
        merchant = newMerchant;
    }

    // ──────────────────────────────────────────
    //  수수료율 관리 (Owner 전용)
    // ──────────────────────────────────────────

    function setFeeRate(uint256 newFeeRate) external onlyOwner {
        require(newFeeRate <= MAX_FEE_RATE, "CafePayment: fee too high");
        emit FeeRateUpdated(feeRate, newFeeRate);
        feeRate = newFeeRate;
    }

    // ──────────────────────────────────────────
    //  수수료 인출 (Owner 전용)
    // ──────────────────────────────────────────

    function withdrawFees(address token) external onlyOwner nonReentrant {
        uint256 amount = collectedFees[token];
        require(amount > 0, "CafePayment: no fees to withdraw");
        collectedFees[token] = 0;
        require(
            IERC20(token).transfer(owner(), amount),
            "CafePayment: withdraw failed"
        );
        emit Withdrawn(token, amount);
    }
}
