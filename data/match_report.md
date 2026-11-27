# Match report

Generated 2026-11-27 from `data/volvo_price_tracker.csv` (29 scrapes, 2026-05-06 to 2026-11-27).

## Input cleaning
- Raw rows: 22269
- Exact duplicate rows removed: 1396
- Same listing_id twice on one date, removed: 0
- Observations kept: 20873

Exact duplicates by date:

| scrape_date | rows | kept | removed |
|---|---|---|---|
| 2026-05-06 | 2212 | 1104 | 1108 |
| 2026-05-10 | 1084 | 1052 | 32 |
| 2026-05-17 | 1054 | 1039 | 15 |
| 2026-05-24 | 1026 | 1003 | 23 |
| 2026-05-31 | 1012 | 1002 | 10 |
| 2026-06-07 | 1002 | 997 | 5 |
| 2026-06-21 | 975 | 974 | 1 |
| 2026-06-28 | 935 | 934 | 1 |
| 2026-07-05 | 929 | 920 | 9 |
| 2026-07-12 | 860 | 851 | 9 |
| 2026-07-19 | 952 | 932 | 20 |
| 2026-07-26 | 869 | 842 | 27 |
| 2026-08-02 | 769 | 758 | 11 |
| 2026-08-16 | 632 | 615 | 17 |
| 2026-08-23 | 585 | 571 | 14 |
| 2026-08-30 | 548 | 543 | 5 |
| 2026-09-06 | 507 | 490 | 17 |
| 2026-10-04 | 471 | 467 | 4 |
| 2026-10-11 | 511 | 486 | 25 |
| 2026-10-18 | 451 | 445 | 6 |
| 2026-10-25 | 484 | 474 | 10 |
| 2026-11-01 | 492 | 483 | 9 |
| 2026-11-15 | 582 | 564 | 18 |


Scrapes judged incomplete (absence there doesn't count towards "sold"):

| scrape_date | model_year | n | ref |
|---|---|---|---|
| 2026-08-09 | 2023 | 0 | 162 |
| 2026-08-09 | 2024 | 0 | 84 |
| 2026-08-09 | 2025 | 23 | 314 |


Gaps of more than 8 days between scrapes:

| from | to | days |
|---|---|---|
| 2026-09-13 | 2026-09-27 | 14 |
| 2026-11-15 | 2026-11-27 | 12 |


## Linking
- Linked by listing_id: 0
- Linked by exact fingerprint: 14815
- Linked by mileage creep (same description, up to 150 mil/week, 10 if a scrape was missed): 439
- Linked despite edited description (same mileage): 780
- Started a new car: 4839
- Of which ambiguous (several candidates, left unlinked): 98 rows

## Cars
- Unique cars: 4839
- Active: 818, presumed sold: 4021
- Cars with at least one fuzzy link: 953
- Cars touched by an ambiguous match: 98
- Seen in only one scrape: 1319
- Already listed at first scrape (true listing date unknown): 1104
- Cars with at least one price drop: 1113

## Ambiguous cases (first 25)

| scrape_date | candidate_car | model | model_year | color | description | description.t | mil | mil.t | dmil | method |
|---|---|---|---|---|---|---|---|---|---|---|
| 2026-05-10 | car00822 | EX40 | 2025 | Fjord Blue | R Core SE//Drag//360-kamera// | R Core SE//Drag//360-kamera// | 4060 | 4014 | 46 | creep |
| 2026-05-10 | car00823 | EX40 | 2025 | Fjord Blue | R Core SE//Drag//360-kamera// | R Core SE//Drag//360-kamera// | 4060 | 4059 | 1 | creep |
| 2026-05-10 | car01048 | EX40 | 2026 | Crystal White | ExtendedRange Plus SE * OUTLET * | ExtendedRange Plus SE | 1213 | 1213 | 0 | desc_change |
| 2026-05-10 | car01048 | EX40 | 2026 | Crystal White | ExtendedRange Plus SE | ExtendedRange Plus SE | 1292 | 1213 | 79 | creep |
| 2026-05-10 | car01057 | EX40 | 2026 | Crystal White | ExtendedRange Plus SE | ExtendedRange Plus SE | 1292 | 1291 | 1 | creep |
| 2026-05-17 | car00537 | XC40 | 2023 | Black Stone | Core Edition | Core Edition | 4421 | 4418 | 3 | creep |
| 2026-05-17 | car00406 | XC40 | 2023 | Black Stone | Core Edition | Core Edition | 4421 | 4315 | 106 | creep |
| 2026-05-24 | car00302 | XC40 | 2023 | Black Stone | Core Edition | Core Edition | 5396 | 5364 | 32 | creep |
| 2026-05-24 | car00294 | XC40 | 2023 | Black Stone | Core Edition | Core Edition | 5396 | 5359 | 37 | creep |
| 2026-05-24 | car00248 | XC40 | 2023 | Black Stone | Core Edition, Baklucka elmanövrerad, Dragkrok | Core Edition | 7220 | 7220 | 0 | desc_change |
| 2026-05-24 | car00562 | XC40 | 2023 | Black Stone | Core Edition, Baklucka elmanövrerad, Dragkrok | Core Edition, Ränta 2,95%, Baklucka elmanövrerad, Dragkrok | 7220 | 7220 | 0 | desc_change |
| 2026-05-24 | car01318 | EC40 | 2025 | Vapour Grey | Core SE//360-Kamera// | Core SE | 4093 | 4093 | 0 | desc_change |
| 2026-05-24 | car01318 | EC40 | 2025 | Vapour Grey | Core SE | Core SE | 4210 | 4093 | 117 | creep |
| 2026-05-24 | car00850 | EX40 | 2025 | Vapour Grey | R Plus Edt//360Kamera//Drag// | Single Motor Extended R Plus Edt//360Kamera//Drag// | 2846 | 2846 | 0 | desc_change |
| 2026-05-24 | car00853 | EX40 | 2025 | Vapour Grey | R Plus Edt//360Kamera//Drag// | R Plus Edt//360Kamera//Drag// | 2846 | 2774 | 72 | creep |
| 2026-05-31 | car00845 | EX40 | 2025 | Vapour Grey | R Plus Edt | R Plus Edt | 2675 | 2595 | 80 | creep |
| 2026-05-31 | car00848 | EX40 | 2025 | Vapour Grey | R Plus Edt | R Plus Edt//360Kamera//Drag// | 2928 | 2928 | 0 | desc_change |
| 2026-05-31 | car01349 | EX40 | 2025 | Vapour Grey | R Plus Edt | R Plus Edt | 2928 | 2788 | 140 | creep |
| 2026-05-31 | car00845 | EX40 | 2025 | Vapour Grey | R Plus Edt | R Plus Edt | 2650 | 2595 | 55 | creep |
| 2026-05-31 | car00845 | EX40 | 2025 | Vapour Grey | R Plus Edt | R Plus Edt | 2648 | 2595 | 53 | creep |
| 2026-05-31 | car00971 | EX90 | 2025 | Sand Dune | Twin Motor Performance Ultra 7sätes | Pilot Assist | Dragkrok | Bose | | Twin Motor Performance Ultra 7sätes | Pilot Assist | Dragkrok | Bose | | 1909 | 1906 | 3 | creep |
| 2026-05-31 | car01551 | EX90 | 2025 | Sand Dune | Twin Motor Performance Ultra 7sätes | Pilot Assist | Dragkrok | Bose | | Ultra 7sätes | Pilot Assist | Dragkrok | Bose | | 1909 | 1909 | 0 | desc_change |
| 2026-06-07 | car01642 | XC40 | 2024 | Silver Dawn | Ultimate//Drag//360-Kamera// | Ultimate | 7460 | 7460 | 0 | desc_change |
| 2026-06-07 | car01642 | XC40 | 2024 | Silver Dawn | Ultimate | Ultimate | 7479 | 7460 | 19 | creep |
| 2026-06-07 | car01681 | EX40 | 2025 | Vapour Grey | R Plus Edt | R Plus Edt | 2811 | 2675 | 136 | creep |


## Fuzzy links (first 25)

| scrape_date | car_id | model | model_year | match_method | prev_desc | description | prev_mil | mil |
|---|---|---|---|---|---|---|---|---|
| 2026-05-10 | car00001 | XC40 | 2021 | desc_change | Pure Electric, backkamera, | Pure Electric / backkamera/ 2.95% ränta | 12383 | 12383 |
| 2026-05-10 | car00028 | C40 Recharge | 2023 | desc_change | Core / Tonade rutor / Navigation / | Core / Tonade rutor / Navigation / 2.95% ränta | 7322 | 7322 |
| 2026-05-10 | car00043 | C40 Recharge | 2023 | creep | Core | 2.95% Ränta | | Core | 2.95% Ränta | | 7309 | 7317 |
| 2026-05-10 | car00067 | C40 Recharge | 2023 | desc_change | Core / Navigation / Panoramaglastak / Backkamera / | Core / Navigation / Panoramaglastak / Backkamera / 2.95% ränta | 4128 | 4128 |
| 2026-05-10 | car00087 | C40 Recharge | 2023 | desc_change | Core Edition / Navigation / Panoramatak/ Backkamera | Core Edition / Navigation / Panoramatak/ Backkamera/ 2.95% ränta | 4405 | 4405 |
| 2026-05-10 | car00102 | C40 Recharge | 2023 | desc_change | Plus / Navigation / Panoramaglastak / Backkamera / | Plus / Navigation / Panoramaglastak / Backkamera / 2.95% ränta | 5746 | 5746 |
| 2026-05-10 | car00109 | C40 Recharge | 2023 | desc_change | Core / Navigation / Klimatpaket / | Core / Navigation / Klimatpaket / 2.95% ränta | 2973 | 2973 |
| 2026-05-10 | car00178 | C40 Recharge | 2023 | creep | Core | Core | 5413 | 5430 |
| 2026-05-10 | car00187 | C40 Recharge | 2023 | desc_change | Ultimate, Panoramatak, 360 kamera | Ultimate, Panoramatak, 360 kamera, 2.95% ränta | 4070 | 4070 |
| 2026-05-10 | car00199 | C40 Recharge | 2023 | creep | Ultimate | Ultimate | 6886 | 6895 |
| 2026-05-10 | car00216 | XC40 | 2023 | desc_change | Core Edition, Backkamera, p-sensorer | Core Edition, Backkamera, p-sensorer, 2.95% ränta | 8545 | 8545 |
| 2026-05-10 | car00220 | XC40 | 2023 | creep | Core Edition //Kamera//Värmare// | Core Edition //Kamera//Värmare// | 8881 | 8941 |
| 2026-05-10 | car00271 | XC40 | 2023 | desc_change | Core | Core Edition / 2,95%* / Navigation / Parkeringssensor fram/bak/ Backkamera, | 6592 | 6592 |
| 2026-05-10 | car00272 | XC40 | 2023 | desc_change | Core / Klimatpaket / | Core / Klimatpaket / 2.95% ränta | 7852 | 7852 |
| 2026-05-10 | car00290 | XC40 | 2023 | desc_change | Core / Navigation / Metallic / | Core / Navigation / Metallic / 2.95% ränta | 6530 | 6530 |
| 2026-05-10 | car00292 | XC40 | 2023 | desc_change | Core / Mörkt tonade rutor / Klimatpaket / | Core / Mörkt tonade rutor / Klimatpaket / 2.95% ränta | 7774 | 7774 |
| 2026-05-10 | car00359 | XC40 | 2023 | desc_change | Core Edition / Navigation / | Core Edition / Navigation / 2.95% ränta | 4840 | 4840 |
| 2026-05-10 | car00362 | XC40 | 2023 | desc_change | Core / Dragkrok / Navigation / | Core / Dragkrok / Navigation / 2.95% ränta | 5856 | 5856 |
| 2026-05-10 | car00363 | XC40 | 2023 | desc_change | Core / Klimatpaket / | Core / Klimatpaket / 2.95% ränta | 5003 | 5003 |
| 2026-05-10 | car00414 | XC40 | 2023 | desc_change | Core / Mörkt tonade rutor / Klimatpaket / | Core / Mörkt tonade rutor / Klimatpaket /2.95% ränta | 4360 | 4360 |
| 2026-05-10 | car00417 | XC40 | 2023 | desc_change | Core / Klimatpaket / Navigation / | Core / Klimatpaket / Navigation / 2.95% ränta | 3069 | 3069 |
| 2026-05-10 | car00418 | XC40 | 2023 | desc_change | Core / Navigation / Mörkt tonade rutor / | Core / Navigation / Mörkt tonade rutor / 2.95% ränta | 4607 | 4607 |
| 2026-05-10 | car00451 | XC40 | 2023 | desc_change | Core / Navigation / Klimatpaket / | Core / Navigation / Klimatpaket / 2.95% ränta | 1995 | 1995 |
| 2026-05-10 | car00452 | XC40 | 2023 | desc_change | Core Edition / Navigation / | Core Edition / Navigation / 2.95% ränta | 2292 | 2292 |
| 2026-05-10 | car00869 | EX40 | 2025 | desc_change | R Plus Edt | Single Motor Extended R Plus Edt | 3052 | 3052 |

