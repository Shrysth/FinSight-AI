# FinSight AI — Personal Finance & Tax Brief Microservices

**FinSight AI** is a Java 21 + Spring Boot microservices application that ingests multi-bank PDF statements (SBI, ICICI, HDFC, etc.), classifies expenses, investments, and savings using **Spring AI (Google Gemini)**, computes Indian Income Tax liabilities for salaried individuals, and generates a downloadable **Personal Financial & Tax Brief PDF** using **OpenPDF**.

Designed specifically to run cleanly inside **GitHub Codespaces (Free Tier / 8 GB RAM)** with zero paid infrastructure dependencies.

---

## Key Features

* **Multi-Bank PDF Ingestion:** Upload statements from multiple banks in a single request, with support for password-protected bank PDFs via **Apache PDFBox**.
* **Privacy-First PII Masking:** Account numbers, PAN details, and sensitive identifiers are scrubbed via regex in Java before any transaction text reaches the LLM.
* **AI Transaction Normalization & Advisory:** Uses **Spring AI** structured outputs to normalize diverse bank statement formats into unified categories (Expenses, SIPs/Investments, Income/Savings) and generate actionable habit recommendations.
* **Deterministic Indian Income Tax Engine:** Calculates exact annual tax liabilities (Old vs. New Tax Regime) and computes a monthly tax-saving reserve target—never relying on LLM arithmetic for tax math.
* **PDF-In → PDF-Out Deliverable:** Compiles spending breakdowns, tax calculations, and AI recommendations into a formatted, downloadable `.pdf` report via **OpenPDF**.
* **Stateless JWT Security with Server-Side Logout:** Full authentication flow (`register`, `login`, `logout` with token revocation) enforced at the API Gateway.

---

## Tech Stack

| Layer | Technology |
| :--- | :--- |
| **Language & Runtime** | Java 21 (Virtual Threads enabled) |
| **Core Framework** | Spring Boot 4.2.0 |
| **Microservices & Routing** | Spring Cloud 2026.0.0 (`Paddington`) — Netflix Eureka, Spring Cloud Gateway, OpenFeign |
| **AI Integration** | Spring AI 2.1.0 (Google Gemini Free Tier API) |
| **PDF Reading & Writing** | Apache PDFBox (Read/Decrypt) + OpenPDF (Generate Report) |
| **Security** | Spring Security + JJWT + Revoked Token Store |
| **Database** | H2 File-Based (Dev/Codespaces) / PostgreSQL (`user_db` & `finance_db` schemas) |
| **Development Environment** | GitHub Codespaces (2-Core / 8 GB RAM container) |

---

## System Architecture

```text
                        ┌──────────────────────┐
                        │   Client / Browser   │
                        │  (Swagger / Postman) │
                        └──────────┬───────────┘
                                   │ HTTP + Bearer JWT
                                   ▼
                        ┌──────────────────────┐
                        │     api-gateway      │◄──────┐
                        │     (Port 8080)      │       │ Service Discovery
                        └────┬────────────┬────┘       │
                             │            │            │
            ┌────────────────┘            └────────────┼───────────┐
            ▼                                          ▼           │
┌───────────────────────┐                  ┌───────────────────────┴──┐
│   user-auth-service   │◄───OpenFeign────►│    finance-ai-service    │
│      (Port 8081)      │   Fetch Profile  │       (Port 8082)        │
└───────────┬───────────┘                  └──────┬─────────────┬─────┘
            │                                     │             │
            ▼                                     ▼             ▼
      ┌───────────┐                         ┌───────────┐ ┌───────────┐
      │  user_db  │                         │finance_db │ │ Gemini AI │
      └───────────┘                         └───────────┘ └───────────┘
                                                  ▲
                                                  │ Registers
                                         ┌────────┴────────┐
                                         │  eureka-server  │
                                         │   (Port 8761)   │
                                         └─────────────────┘

```

### Microservices Overview

| # | Service | Port | Heap Limit | Responsibility |
| --- | --- | --- | --- | --- |
| **1** | `eureka-server` | `8761` | `256m` | Service registry and health monitoring. |
| **2** | `api-gateway` | `8080` | `256m` | Single entry point, CORS, JWT validation filter, and downstream `X-User-Id` header injection. |
| **3** | `user-auth-service` | `8081` | `384m` | User registration, login, server-side logout (`jti` revocation), and financial profile management (annual salary, tax regime). |
| **4** | `finance-ai-service` | `8082` | `512m` | Multi-bank PDF parsing, PII masking, AI categorization, Indian tax computation, report persistence, and OpenPDF brief generation. |

---

## Project Structure

```text
finsight-ai/
├── .devcontainer/
│   └── devcontainer.json          # GitHub Codespaces Java 21 + Maven setup
├── eureka-server/                 # Service Discovery (Port 8761)
├── api-gateway/                   # Edge Router & JWT Security Filter (Port 8080)
├── user-auth-service/             # Auth & User Financial Profile (Port 8081)
├── finance-ai-service/            # PDFBox + Spring AI + Tax Engine + OpenPDF (Port 8082)
├── scripts/
│   ├── start-all.sh               # Starts all 4 services with memory caps (-Xmx)
│   └── stop-all.sh                # Gracefully stops all running services
├── pom.xml                        # Multi-module parent POM
├── ARCHITECTURE.md                # Detailed schema & system design reference
└── README.md

```

---

## REST API Reference (14 Endpoints)

All client requests route through `http://localhost:8080`.

### 1. Authentication & User Profile (`user-auth-service`)

| Method | Endpoint | Auth | Description |
| --- | --- | --- | --- |
| `POST` | `/api/v1/auth/register` | Public | Register a new user with initial `annualSalary` and `preferredTaxRegime` (`NEW`/`OLD`). Returns JWT. |
| `POST` | `/api/v1/auth/login` | Public | Authenticate user credentials and issue a signed JWT. |
| `POST` | `/api/v1/auth/logout` | Bearer JWT | Revoke current JWT (`jti`) in `revoked_tokens` table for true server-side logout. |
| `GET` | `/api/v1/auth/validate` | Internal | Validates token signature and checks revocation status for `api-gateway`. |
| `GET` | `/api/v1/users/profile` | Bearer JWT | Retrieve logged-in user details, annual salary, and tax regime preference. |
| `PUT` | `/api/v1/users/profile` | Bearer JWT | Update annual salary, age group, or tax regime preference. |

### 2. PDF Analysis, Tax Engine & Reports (`finance-ai-service`)

| Method | Endpoint | Auth | Description |
| --- | --- | --- | --- |
| `POST` | `/api/v1/finance/analyze-and-download` | Bearer JWT | **Primary Endpoint:** Upload 1+ bank PDFs (`files[]`, `bankNames[]`, optional `passwords[]`), analyze via AI + Tax Engine, and immediately download `Financial_Tax_Brief.pdf`. |
| `POST` | `/api/v1/finance/analyze` | Bearer JWT | Same analysis pipeline as above, returning structured JSON (`ReportSummaryDTO`) instead of a binary PDF. |
| `GET` | `/api/v1/finance/reports` | Bearer JWT | List all previously generated financial briefs for the authenticated user. |
| `GET` | `/api/v1/finance/reports/{reportId}` | Bearer JWT | Retrieve full JSON analytics, category splits, and AI recommendations for a saved report. |
| `GET` | `/api/v1/finance/reports/{reportId}/download` | Bearer JWT | Re-generate and download the formatted `.pdf` brief from saved database records. |
| `GET` | `/api/v1/finance/reports/{reportId}/transactions` | Bearer JWT | List itemized AI-categorized transactions (supports `?category=` and `?bank=` filters). |
| `POST` | `/api/v1/finance/tax/simulate` | Bearer JWT | Standalone "What-If" Indian Income Tax simulator comparing Old vs. New Regime liabilities. |
| `DELETE` | `/api/v1/finance/reports/{reportId}` | Bearer JWT | Delete a saved financial report and its associated transactions. |

---

## Indian Income Tax Calculation Logic (Salaried)

The deterministic tax engine computes liabilities prior to AI narrative generation. Under the **New Tax Regime (u/s 115BAC)** for salaried individuals (including the **₹75,000 Standard Deduction**):

| Net Taxable Income Slab | Tax Rate |
| --- | --- |
| Up to ₹4,00,000 | Nil |
| ₹4,00,001 – ₹8,00,000 | 5% |
| ₹8,00,001 – ₹12,00,000 | 10% |
| ₹12,00,001 – ₹16,00,000 | 15% |
| ₹16,00,001 – ₹20,00,000 | 20% |
| ₹20,00,001 – ₹24,00,000 | 25% |
| Above ₹24,00,000 | 30% |

*Applies Section 87A rebate (zero tax up to ₹12,00,000 net taxable income) and adds **4% Health & Education Cess** on payable tax, then divides remaining liability by remaining financial year months to recommend a monthly tax-saving reserve.*

---

## Getting Started in GitHub Codespaces ($0 Setup)

### 1. Prerequisites

* A GitHub account (Free tier provides 120 core-hours/month).
* A free **Google Gemini API Key** from [Google AI Studio](https://aistudio.google.com/).

### 2. Launch Codespace

1. Click **Code → Codespaces → Create codespace on main**.
2. Select the **2-core (8 GB RAM)** machine type to maximize free monthly hours and comfortably fit all 4 JVMs (~1.5 GB total RAM).

### 3. Configure Environment Variables

Create a `.env` file in the project root (already git-ignored):

```bash
GEMINI_API_KEY=your_google_ai_studio_api_key_here
JWT_SECRET=your_256_bit_base64_encoded_secret_key_here

```

### 4. Build & Run All Microservices

```bash
# Build all 4 Maven modules
mvn clean package -DskipTests

# Start Eureka, Gateway, Auth Service, and Finance AI Service with memory caps
chmod +x scripts/*.sh
./scripts/start-all.sh

```

Verify all services are registered by opening the Eureka Dashboard on forwarded port **`8761`**.

---

## Quick Test Workflow (End-to-End)

1. **Register a User (Annual Salary: ₹16,00,000):**
```bash
curl -X POST http://localhost:8080/api/v1/auth/register \
  -H "Content-Type: application/json" \
  -d '{
    "fullName": "Rahul Sharma",
    "email": "rahul@example.com",
    "password": "Password@123",
    "annualSalary": 1600000,
    "preferredTaxRegime": "NEW"
  }'

```


2. **Upload Bank PDFs & Download Custom Financial Brief PDF:**
```bash
curl -X POST http://localhost:8080/api/v1/finance/analyze-and-download \
  -H "Authorization: Bearer <YOUR_JWT_TOKEN>" \
  -F "files=@sample-sbi.pdf" \
  -F "bankNames=SBI" \
  -F "files=@sample-icici.pdf" \
  -F "bankNames=ICICI" \
  --output Financial_Tax_Brief.pdf

```


3. **Stop Services & Save Codespace Hours:**
```bash
./scripts/stop-all.sh

```


*(Remember to stop or delete inactive Codespaces from `github.com/codespaces` to preserve your free storage quota.)*

---

## License

This project is open-source and available under the [MIT License](https://www.google.com/search?q=LICENSE).

```

```
