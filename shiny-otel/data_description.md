# ADSL — Subject-Level Analysis Dataset (CDISC ADaM)

Simulated clinical-trial subject-level data (one row per subject) from the `random.cdisc.data` R package. N = 400 subjects.

## Key columns

- **USUBJID**: Unique subject identifier.
- **STUDYID**: Study identifier.
- **AGE** (integer): Age in years at screening.
- **AGEU**: Age units (typically "YEARS").
- **AGEGR1** (derived): Age group — one of "<65", "65-<75", ">=75".
- **SEX**: F / M / U.
- **RACE**: Race category.
- **ETHNIC**: Ethnicity.
- **COUNTRY**: 3-letter country code.
- **ARM / ARMCD**: Planned treatment arm and code (e.g., "A: Drug X", "B: Placebo", "C: Combination").
- **ACTARM**: Actual treatment arm received.
- **TRT01P / TRT01A**: Planned / actual treatment for period 1.
- **SAFFL** (Y/N): Safety population flag.
- **ITTFL** (Y/N): Intent-to-treat population flag.
- **BEP01FL** (Y/N): Biomarker evaluable population flag.
- **BMEASIFL** (Y/N): Biomarker measurable-at-baseline flag.
- **DCSREAS**: Reason for discontinuation from study (NA if completed).
- **EOSSTT**: End-of-study status (COMPLETED, DISCONTINUED, ONGOING).
- **BMRKR1** (numeric): Continuous biomarker 1 at baseline.
- **BMRKR2**: Categorical biomarker 2 (LOW / MEDIUM / HIGH).
- **STRATA1 / STRATA2**: Randomization stratification factors.

## Guidance for queries

- Treat flag columns (SAFFL, ITTFL, BEP01FL, BMEASIFL) as "Y"/"N" strings.
- When users mention "the safety population", filter `SAFFL = 'Y'`.
- When users mention "completed the study", use `EOSSTT = 'COMPLETED'`.
- Numeric columns suitable for aggregation: AGE, BMRKR1.
- Typical grouping columns: ARM, ARMCD, SEX, RACE, COUNTRY, AGEGR1, BMRKR2, STRATA1, STRATA2.
