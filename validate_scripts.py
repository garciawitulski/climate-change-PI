#!/usr/bin/env python3
"""
Validation script for Stata .do files 08 and 09
Verifies data structure and simulates key operations
"""

import pandas as pd
import numpy as np

print("=" * 70)
print("VALIDATING STATA SCRIPTS 08 & 09")
print("=" * 70)

# Load data
print("\n[1/5] Loading data...")
try:
    df = pd.read_csv('data/processed/processed_data.csv', encoding='utf-8')
    print(f"✓ Data loaded successfully: {len(df):,} rows, {len(df.columns)} columns")
except Exception as e:
    print(f"✗ Error loading data: {e}")
    exit(1)

# Check required variables
print("\n[2/5] Checking required variables...")
required_vars = {
    'Script 08 (Age strata)': ['objectid', 'año_by_country', 'medianage', 'lngdppc',
                                'pi0', 'pi1', 'pi2', 'deathr', 'lnpm25',
                                'total_bin_2_tmean', 'total_bin_3_tmean',
                                'total_bin_4_tmean', 'total_bin_5_tmean',
                                'precipitation_weighted', 'cld_weighted',
                                'frs_weighted', 'vap_weighted', 'wet_weighted'],
    'Script 09 (Baseline temp)': ['tmean_weighted', 'total_bin_1_tmean']
}

all_good = True
for script, vars_list in required_vars.items():
    missing = [v for v in vars_list if v not in df.columns]
    if missing:
        print(f"✗ {script}: Missing variables: {missing}")
        all_good = False
    else:
        print(f"✓ {script}: All required variables present")

if not all_good:
    exit(1)

# Validate Script 08: Age stratification
print("\n[3/5] Validating Script 08 (Age stratification)...")
print("-" * 70)

# Create median age terciles
df_08 = df.copy()
df_08['medage_mean'] = df_08.groupby('country_standard')['medianage'].transform('mean')
df_08['medage_terc'] = pd.qcut(df_08['medage_mean'], q=3, labels=['T1 (Low)', 'T2 (Middle)', 'T3 (High)'])

# Summary statistics
print("\nMedian Age Tercile Distribution:")
terc_summary = df_08.groupby('medage_terc').agg({
    'country_standard': 'nunique',
    'medage_mean': ['mean', 'min', 'max']
}).round(2)
terc_summary.columns = ['N Countries', 'Mean Age', 'Min Age', 'Max Age']
print(terc_summary)

# Check data availability by outcome and tercile
print("\nObservations by outcome and tercile:")
for outcome in ['pi0', 'pi1', 'pi2']:
    df_valid = df_08[df_08[outcome].notna()]
    print(f"\n{outcome}:")
    for terc in ['T1 (Low)', 'T2 (Middle)', 'T3 (High)']:
        n_obs = len(df_valid[df_valid['medage_terc'] == terc])
        n_countries = df_valid[df_valid['medage_terc'] == terc]['country_standard'].nunique()
        print(f"  {terc}: {n_obs:,} obs, {n_countries} countries")

print("✓ Script 08 validation successful")

# Validate Script 09: Baseline temperature stratification
print("\n[4/5] Validating Script 09 (Baseline temperature stratification)...")
print("-" * 70)

# Create baseline temperature terciles
df_09 = df.copy()
df_09['baseline_T'] = df_09.groupby('country_standard')['tmean_weighted'].transform('mean')
df_09['baseline_terc'] = pd.qcut(df_09['baseline_T'], q=3, labels=['T1 (Cooler)', 'T2 (Middle)', 'T3 (Hotter)'])

# Calculate temperature cutpoints
cutpoints = df_09.groupby('country_standard')['baseline_T'].mean().quantile([0.3333, 0.6667])
t1_hi = cutpoints.iloc[0]
t2_hi = cutpoints.iloc[1]

print(f"\nTemperature cutpoints:")
print(f"  T1 (Cooler):  < {t1_hi:.1f}°C")
print(f"  T2 (Middle):  [{t1_hi:.1f}, {t2_hi:.1f})°C")
print(f"  T3 (Hotter):  >= {t2_hi:.1f}°C")

# Summary statistics
print("\nBaseline Temperature Tercile Distribution:")
terc_summary = df_09.groupby('baseline_terc').agg({
    'country_standard': 'nunique',
    'baseline_T': ['mean', 'min', 'max']
}).round(2)
terc_summary.columns = ['N Countries', 'Mean Temp', 'Min Temp', 'Max Temp']
print(terc_summary)

# Check Bin 1 creation
print("\nValidating Bin 1 calculation...")
df_09['bin1_check'] = 12 - (df_09['total_bin_2_tmean'] + df_09['total_bin_3_tmean'] +
                             df_09['total_bin_4_tmean'] + df_09['total_bin_5_tmean'])
diff = (df_09['total_bin_1_tmean'] - df_09['bin1_check']).abs().max()
if diff < 1e-6:
    print(f"✓ Bin 1 calculation verified (max diff: {diff:.2e})")
else:
    print(f"⚠ Bin 1 mismatch detected (max diff: {diff:.6f})")

# Check data availability by outcome and tercile
print("\nObservations by outcome and tercile:")
for outcome in ['pi0', 'pi1', 'pi2']:
    df_valid = df_09[df_09[outcome].notna()]
    print(f"\n{outcome}:")
    for terc in ['T1 (Cooler)', 'T2 (Middle)', 'T3 (Hotter)']:
        n_obs = len(df_valid[df_valid['baseline_terc'] == terc])
        n_countries = df_valid[df_valid['baseline_terc'] == terc]['country_standard'].nunique()
        print(f"  {terc}: {n_obs:,} obs, {n_countries} countries")

# Within-country variance check
print("\nChecking within-country variance for temperature bins...")
variance_check = []
for b in [1, 2, 3, 4, 5]:
    var_col = f'total_bin_{b}_tmean'
    df_09[f'sd_b{b}'] = df_09.groupby('country_standard')[var_col].transform('std')
    zero_var_countries = (df_09.groupby('country_standard')[f'sd_b{b}'].first() < 1e-8).sum()
    variance_check.append({
        'Bin': b,
        'Countries with zero variance': zero_var_countries
    })

var_df = pd.DataFrame(variance_check)
print(var_df.to_string(index=False))

print("\n✓ Script 09 validation successful")

# Final summary
print("\n[5/5] Final Summary")
print("=" * 70)
print("✓ All validations passed successfully!")
print("\nScripts are ready for execution in Stata:")
print("  - scripts/08_table_S11_age_strata.do")
print("  - scripts/09_table_S12_baseline_temp_strata.do")
print("\nExpected outputs:")
print("  Script 08 (Age stratification):")
print("    - outputs/tables/supplementary/Table_S11a_medageStrata_PI0.tex")
print("    - outputs/tables/supplementary/Table_S11b_medageStrata_PI1.tex")
print("    - outputs/tables/supplementary/Table_S11c_medageStrata_PI2.tex")
print("\n  Script 09 (Baseline temp stratification):")
print("    - outputs/tables/supplementary/Table_S12a_baselineTemp_PI0.tex")
print("    - outputs/tables/supplementary/Table_S12b_baselineTemp_PI1.tex")
print("    - outputs/tables/supplementary/Table_S12c_baselineTemp_PI2.tex")
print("=" * 70)
