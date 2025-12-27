# 🏗️ Over‑Collateralized Lending – Hướng dẫn chạy theo từng Checkpoint

Tài liệu này hướng dẫn **từng bước chạy và hoàn thành các checkpoint** của challenge **Over‑Collateralized Lending** sử dụng **Scaffold‑ETH 2**.

---

## 📦 Yêu cầu môi trường

Cài sẵn các công cụ sau:

* **Node.js >= v20.18.3**
* **Yarn** (v1 hoặc v2+)
* **Git**

Kiểm tra nhanh:

```bash
node -v
yarn -v
git --version
```

---

## 🚀 Khởi động dự án

Clone repo và cài dependencies:

```bash
git clone <repo-url>
cd scaffold-eth-2
yarn install
```

---

## ✅ Checkpoint 0 – Environment

### Mục tiêu

* Chạy blockchain local
* Deploy contracts
* Chạy frontend

### Các bước

Mở **3 terminal**:

**Terminal 1 – Blockchain local**

```bash
yarn chain
```

**Terminal 2 – Deploy contracts**

```bash
yarn deploy
```

**Terminal 3 – Frontend**

```bash
yarn start
```

Mở trình duyệt:

```
http://localhost:3000
```

> Khi thay đổi contract: dừng `yarn chain` → chạy lại `yarn chain` → `yarn deploy --reset`

---

## ✅ Checkpoint 1 – Lending Contract Overview

### Mục tiêu

* Hiểu vai trò các contract:

  * `Corn` (ERC20)
  * `CornDEX` (DEX + price oracle)
  * `Lending` (contract chính)
  * `MovePrice` (điều chỉnh giá)

### Việc cần làm

* Mở file:

```
packages/hardhat/contracts/Lending.sol
```

* Đọc toàn bộ function rỗng và hình dung logic

---

## ✅ Checkpoint 2 – Add & Withdraw Collateral

### Mục tiêu

* Nạp ETH làm collateral
* Rút ETH đã nạp

### Functions cần implement

* `addCollateral()`
* `withdrawCollateral(uint256 amount)`

### Sau khi code xong

```bash
yarn deploy --reset
```

Vào frontend:

* Faucet ETH
* Add Collateral
* Withdraw Collateral

> Frontend phải update realtime sau mỗi action

---

## ✅ Checkpoint 3 – Helper Methods

### Mục tiêu

* Tính giá trị collateral
* Tính tỷ lệ thế chấp
* Kiểm tra liquidation

### Functions

* `calculateCollateralValue(address)`
* `_calculatePositionRatio(address)`
* `isLiquidatable(address)`
* `_validatePosition(address)`

### Kiến thức quan trọng

* Fixed‑point math (`1e18`)
* Tránh precision loss trong Solidity

---

## ✅ Checkpoint 4 – Borrow & Repay CORN

### Mục tiêu

* Borrow CORN dựa trên collateral
* Repay CORN

### Functions

* `borrowCorn(uint256 borrowAmount)`
* `repayCorn(uint256 repayAmount)`

### Lưu ý

* Phải `approve` CORN trước khi repay
* Không được borrow vượt quá 120%

Sau khi code:

```bash
yarn deploy --reset
```

Test:

* Borrow CORN
* Thay đổi giá CORN
* Repay CORN

---

## ✅ Checkpoint 5 – Liquidation Mechanism

### Mục tiêu

* Thanh lý position không an toàn
* Thưởng 10% cho liquidator

### Function

* `liquidate(address user)`

### Điều kiện

* Position phải < 120%
* Liquidator phải có đủ CORN

### Test

* Mở 2 ví (2 tab trình duyệt)
* 1 ví borrow
* 1 ví mua CORN và liquidate

```bash
yarn deploy --reset
```

---

## ✅ Checkpoint 6 – Final Touches & Simulation

### Bổ sung

* Thêm `_validatePosition` vào `withdrawCollateral`
* Chỉ check nếu user có debt

### Chạy mô phỏng market

```bash
yarn simulate
```

Xem bots tự động:

* Borrow
* Repay
* Liquidate

---

## 🛰️ Checkpoint 7 – Deploy Testnet

### Tạo deployer

```bash
yarn generate
yarn account
```

### Gửi ETH testnet

* Sepolia: ~0.05 ETH
* Optimism Sepolia: ~0.01 ETH

### Deploy

```bash
yarn deploy --network sepolia
```

---

## 🚢 Checkpoint 8 – Deploy Frontend

### Cấu hình network

File:

```
packages/nextjs/scaffold.config.ts
```

Đổi:

```ts
targetNetwork: chains.sepolia
```

### Deploy Vercel

```bash
yarn vercel
yarn vercel --prod
```
Frontend được deploy: 
```
https://nextjs-pdn7829rd-lab01s-projects.vercel.app
```

---

## 📜 Checkpoint 9 – Verify Contract

```bash
yarn verify --network sepolia
```

Sau đó:

* Mở Etherscan
* Copy link submit lên **SpeedRunEthereum.com**, Dưới đây là link đã được submit:
```
https://sepolia.etherscan.io/address/0xd3461bab851695A0810DF16C4b747589cc939B13
```
---

## 🎯 Hoàn thành

