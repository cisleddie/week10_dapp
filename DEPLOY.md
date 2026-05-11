# FreCoin DApp — 배포 가이드

## 파일 구성
```
frecoin-dapp/
├── FreCoin.sol       — FRE 스테이블코인 컨트랙트
├── CafePayment.sol   — 카페 결제 컨트랙트
├── dapp.html         — 프론트엔드 DApp
└── DEPLOY.md         — 이 파일
```

---

## 1. Remix로 컨트랙트 배포

### 환경 설정
1. [Remix IDE](https://remix.ethereum.org) 접속
2. OpenZeppelin 패키지 설치 (터미널):
   ```
   npm install @openzeppelin/contracts
   ```
   또는 Remix에서 import URL로 직접 사용:
   ```solidity
   import "@openzeppelin/contracts/token/ERC20/ERC20.sol";
   ```

### MetaMask에 GIWA 체인 추가
| 항목 | 값 |
|------|-----|
| 네트워크 이름 | GIWA Testnet |
| RPC URL | https://giwa-testnet.nodit.io |
| Chain ID | (Nodit 대시보드에서 확인) |
| 통화 기호 | ETH |

### FreCoin.sol 배포 순서
1. Remix에서 `FreCoin.sol` 컴파일 (Solidity ^0.8.28)
2. Deploy 탭 → Environment: `Injected Provider - MetaMask`
3. Constructor 인자:
   - `initialOwner`: 배포자 주소 (프랜차이즈)
   - `initialPauser`: 배포자 주소 (또는 별도 pauser)
4. Deploy 클릭 → MetaMask 서명
5. **배포된 FreCoin 주소 복사**

### CafePayment.sol 배포 순서
1. `CafePayment.sol` 컴파일
2. Constructor 인자:
   - `initialOwner`: 프랜차이즈 주소
   - `initialMerchant`: 카페 오너 주소
   - `initialFeeRate`: `200` (2%)
   - `freToken`: FreCoin 배포 주소
3. Deploy → **배포된 CafePayment 주소 복사**

---

## 2. Minter 등록 (필수!)

FreCoin을 발행하려면 Owner가 Minter를 등록해야 합니다.

```
FreCoin.configureMinter(
  minterAddress,   // 발행할 주소
  1000000          // 최대 발행 한도 (FRE)
)
```

DApp의 "관리자 기능 > Minter 등록" 탭에서도 가능합니다.

---

## 3. DApp 사용

1. `dapp.html`을 브라우저에서 직접 열기 (로컬 서버 불필요)
2. "네트워크 설정" 패널에 주소 입력:
   - RPC URL: Nodit GIWA RPC
   - Chain ID: GIWA Chain ID
   - FreCoin 주소: 위에서 복사한 주소
   - CafePayment 주소: 위에서 복사한 주소
3. "저장 & 적용" 클릭
4. "Connect Wallet" 클릭 → MetaMask 연결

---

## 4. 결제 흐름

```
고객 지갑
   │
   ① freContract.approve(paymentContract, amount)
   │   → 고객이 Payment 컨트랙트에 FRE 사용 권한 부여
   │
   ② paymentContract.pay(freAddr, amount)
   │   → 컨트랙트가 transferFrom으로 FRE를 가져감
   │
   ├── amount - fee  →  Merchant (카페 오너)
   └── fee           →  Contract (프랜차이즈가 나중에 인출)
```

---

## 5. 주요 함수 정리

### FreCoin
| 함수 | 역할 | 호출자 |
|------|------|--------|
| `configureMinter(addr, limit)` | Minter 등록 | Owner |
| `mint(to, amount)` | FRE 발행 | Minter |
| `burn(amount)` | FRE 소각 | Minter |
| `blacklist(addr)` | 주소 차단 | Owner |
| `pause()` / `unpause()` | 컨트랙트 일시중지 | Pauser |

### CafePayment
| 함수 | 역할 | 호출자 |
|------|------|--------|
| `pay(token, amount)` | FRE 결제 | 고객 |
| `setFeeRate(bps)` | 수수료율 설정 | Owner |
| `setMerchant(addr)` | 카페 오너 변경 | Owner |
| `withdrawFees(token)` | 수수료 인출 | Owner |
| `addWhitelistedToken(token)` | 결제 토큰 추가 | Owner |

---

## 6. Nodit API 활용 (선택)

Nodit을 통해 GIWA 체인 이벤트를 구독할 수 있습니다:

```javascript
// 결제 이벤트 실시간 구독 (WebSocket)
const wsProvider = new ethers.WebSocketProvider("wss://giwa-testnet.nodit.io/ws");
const paymentContract = new ethers.Contract(PAYMENT_ADDR, PAYMENT_ABI, wsProvider);

paymentContract.on("Paid", (payer, token, amount, fee, method, timestamp) => {
  console.log(`결제 감지: ${payer} → ${amount} FRE (수수료: ${fee})`);
});
```
