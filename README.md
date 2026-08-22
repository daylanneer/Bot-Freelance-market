# BOT Freelance Market

A decentralized freelance job board on BOT Chain. Clients post jobs with BOT bounties, freelancers accept and deliver, payment released on approval.

## Features
- Post jobs with BOT budget (held in escrow)
- Freelancers browse and accept open jobs
- Client approves work → automatic payment with 2.5% platform fee
- Dispute resolution by platform admin
- Cancel open jobs with full refund
- Demo Mode for testing without blockchain

## Quick Start
```bash
npm install && npx hardhat compile && npx hardhat test
npx hardhat run scripts/deploy.js --network botchain_testnet
```

## Deploy on Vercel
Push to GitHub → import on Vercel → auto-deploys from `frontend/` directory.
