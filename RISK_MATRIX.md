# Risk Matrix — GlucDose Smart Insulin Assistant
### ISO 14971:2019 Risk Management — Appendix D

**Document status:** Living document — updated with every [AlgorithmVersion] bump  
**Last updated:** 2024-01-01  
**Clinical reviewer:** Required before each production release

---

## Severity Scale

| Level | Label       | Definition |
|-------|-------------|------------|
| 5     | Catastrophic | Death or permanent injury |
| 4     | Critical    | Irreversible severe harm (e.g., severe hypoglycaemia + seizure) |
| 3     | Serious     | Reversible severe harm (e.g., hospitalisation) |
| 2     | Moderate    | Reversible moderate harm (e.g., symptomatic hypoglycaemia) |
| 1     | Negligible  | Minor discomfort, no clinical significance |

## Likelihood Scale

| Level | Label       | Definition |
|-------|-------------|------------|
| 5     | Frequent    | Likely to occur many times per year per user |
| 4     | Probable    | Likely to occur at least once per user per year |
| 3     | Occasional  | Likely to occur a few times in the product lifetime |
| 2     | Remote      | Unlikely but possible in product lifetime |
| 1     | Improbable  | Very unlikely; only in extreme circumstances |

## Risk Acceptability
- **RPN ≥ 15** → Unacceptable — must be eliminated
- **RPN 8–14** → ALARP — reduce to As Low As Reasonably Practicable
- **RPN ≤ 7**  → Acceptable with monitoring

---

## Risk Register

| ID   | Hazard | Cause | Effect | Severity | Likelihood | RPN (pre) | Mitigation | Residual Likelihood | RPN (post) | Rule |
|------|--------|-------|--------|----------|------------|-----------|------------|--------------------|---------| ----|
| H-01 | Insulin overdose from data entry error (10× typo) | User enters "100" instead of "10" carbs | Severe hypoglycaemia, hospitalisation | 4 | 3 | **12** | Absolute dose ceiling (20 U); value object max carbs 400 g; dose step floor; mandatory confirmation | 1 | **4** | R101 |
| H-02 | Dose administered during hypoglycaemia | User injects during BG < 40 | Death or severe brain injury | 5 | 2 | **10** | Hard block R001 — non-overrideable; BG validation before any calculation | 1 | **5** | R001 |
| H-03 | Dose administered during Level 1 hypo | User injects without awareness (BG 40–69) | Severe symptomatic hypoglycaemia | 4 | 3 | **12** | Warning R201 — mandatory acknowledgement; recommended action displayed | 2 | **8** | R201 |
| H-04 | IOB stacking overdose | User injects before previous dose is cleared | Hypoglycaemia | 4 | 3 | **12** | Walsh IOB deduction in formula; soft block R102 at 70% fraction; warning R203 at threshold | 2 | **8** | R102, R203 |
| H-05 | Rapid repeat injection | User injects again within 15 min | Stacking / hypoglycaemia | 3 | 4 | **12** | Soft block R103 — 15-min interval gate; IOB already deducted | 2 | **6** | R103 |
| H-06 | Calculation with corrupt profile (zero ISF) | User has ISF = 0 or corrupted storage | Division by zero → NaN dose | 5 | 2 | **10** | ISF VO minimum 5.0; data integrity rule R002 blocks NaN/Inf | 1 | **5** | R002 |
| H-07 | Unit confusion (mg/dL vs mmol/L) | User inputs mmol/L in mg/dL field | 18× factor error in dose | 5 | 3 | **15** | UnitSystem abstraction; single internal representation mg/dL; unit-labelled input fields | 1 | **5** | Domain |
| H-08 | Dose rounded UP instead of DOWN | Floating-point rounding error | Patient receives more insulin than calculated | 3 | 2 | **6** | PrecisionMath.floorToStep — always floor, never round | 1 | **3** | Phase 4 |
| H-09 | Incomplete profile used in calculation | First-run before profile is complete | Default ISF/ICR values produce incorrect dose | 4 | 3 | **12** | R004 hard blocks calculation until profile complete | 1 | **4** | R004 |
| H-10 | Prediction misclassifies hypo risk | AI model predicts safe BG when hypo is coming | User does not eat preventive carbs | 4 | 2 | **8** | Hybrid deterministic model (Phase 1) before ML; safety hook triggers at predicted BG < 70 | 2 | **8** | AI |
| H-11 | Severe hyperglycaemia treated with dose only | DKA/HHS not recognised | Delayed treatment → organ damage | 4 | 2 | **8** | Warning R202 at BG > 300 with DKA recommendation | 2 | **8** | R202 |
| H-12 | Accidental tap confirms dose | User taps Confirm unintentionally | Unintended injection | 3 | 3 | **9** | 3-second hold-to-confirm; mandatory delay before confirmation available | 1 | **3** | UX |
| H-13 | Encryption failure exposes PHI | Key rotation failure or storage corruption | Privacy breach (HIPAA/GDPR) | 3 | 1 | **3** | Encryption self-test at bootstrap; blocks launch if key is corrupt | 1 | **3** | Security |
| H-14 | Audit log gap (crash before write) | App crash after calculation but before log | Loss of traceability | 2 | 2 | **4** | Emergency ring buffer; flush on next launch | 1 | **2** | Audit |
| H-15 | Negative dose shown as valid | IOB exceeds calculated dose | User confused; might ignore zero result | 1 | 3 | **3** | Clamp to zero + R206 explanation flag | 1 | **1** | R206 |
| H-16 | Food GI data error | Incorrect GI for a Saudi food item | Wrong absorption curve in prediction | 2 | 2 | **4** | Structured FoodItem entity; GI validated 1–100; food database peer-reviewed | 1 | **2** | Data |

---

## Summary

| RPN Range | Pre-mitigation | Post-mitigation |
|-----------|----------------|-----------------|
| ≥ 15 (Unacceptable) | 1 (H-07) | 0 |
| 8–14 (ALARP) | 9 | 4 |
| ≤ 7 (Acceptable) | 6 | 12 |

All risks reduced to ALARP or acceptable post-mitigation.

---

*This document must be reviewed by a qualified clinical engineer before each production release and whenever [AlgorithmVersion] changes.*
