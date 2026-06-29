# Energy Systems Modelling — Regulatory Rules for Renewable Hydrogen

### The Effects of Regulatory Rules for Renewable Hydrogen — Examination of the Change in Energy System Cost

A term-paper study and accompanying energy-system optimisation model examining how the
European Union's regulatory requirements for **renewable hydrogen** reshape the cost and
investment pathways of a coupled European energy system on the road to 2050.

**Authors:** Toyah Hohenstein · Leonard Schmitz · Paul Weishaupt · Franz Wendel
**Supervisor:** Dr. Konstantin Löffler
**Course:** Energy Sector Modelling (EW MOD), Technische Universität Berlin —
Faculty VII (Economics & Management), Chair of Economics and Infrastructure Policy (WIP)
**Date:** September 2025

📄 **The full paper is in [`report/`](report/).**

---

## Abstract

This paper investigates the impact of the European Union's regulatory framework for
renewable hydrogen — focusing on the requirements of *additionality*, *temporal
correlation*, and *geographical correlation* — on energy-system costs and investment
pathways. Using an extended energy-system optimisation model, four scenarios are analysed
stepwise, ranging from an unconstrained baseline to full regulatory compliance. Results
show that system costs increase by **21.1 %** under the full regulatory regime, with
geographical correlation driving the largest share of additional costs. Compliance with
the rules leads to a **29 %** increase in newly built renewable energy capacity and a
**52 %** rise in electrolyser capacity, reflecting the need for greater flexibility in
matching renewable generation with hydrogen production. The renewable share grows from
**45 % to 58.4 %**, while total emissions remain largely unaffected until 2040 and reach
net-zero by 2050 through carbon capture and storage. Trade volumes decline as regional
self-sufficiency gains importance, and unmet demand occurs only under the strictest
scenario, signalling potential risks for system reliability. Overall, the results suggest
that renewable hydrogen regulation effectively stimulates renewable deployment and supports
decarbonisation, but at the cost of higher system expenditures and reduced flexibility.
Simplifying assumptions in temporal and spatial modelling likely overestimate costs,
highlighting the importance of future research with higher temporal resolution and more
detailed spatial representation.

---

## Background: the EU rules for renewable hydrogen

To qualify as a **Renewable Fuel of Non-Biological Origin (RFNBO)** — i.e. "renewable"
hydrogen — the electricity used for electrolysis must satisfy
**Commission Delegated Regulation (EU) 2023/1184**, which rests on three pillars:

| Pillar | Requirement (simplified) |
| --- | --- |
| **Additionality** | The renewable electricity must come from *newly built* renewable installations, so hydrogen demand does not cannibalise existing green power. |
| **Temporal correlation** | Renewable generation and electrolyser consumption must be matched within the same time window (moving towards hourly matching). |
| **Geographical correlation** | Renewable generation and the electrolyser must be located in the same (or an adjacent) region / bidding zone. |

Each pillar makes renewable hydrogen more demanding to produce. This study translates them
into optimisation constraints and measures their isolated and combined effect on system cost.

## The model

The study uses a **bottom-up, least-cost optimisation** of investment and dispatch across a
coupled European energy system. It is a linear (mixed-integer) program implemented in Julia
([JuMP](https://jump.dev/)) and solved with Gurobi. The objective minimises total discounted
system cost — investment, variable, storage and inter-regional trade cost, net of salvage
value, with a penalty on any unmet demand.

| Dimension | Coverage |
| --- | --- |
| **Regions** | Germany, Denmark, France, Norway, United Kingdom, Spain — linked by inter-regional trade |
| **Horizon** | 2020 → 2050 in 10-year steps (5 % discount rate) |
| **Time** | 120 representative hours scaled to a full year (full 8760-hour profiles also provided) |
| **Energy carriers** | Power, buildings heat, hydrogen, passenger mobility, plus coal, gas, oil, biomass, nuclear |
| **Technologies** | 37 — power plants, CHP, building heat, road mobility, resource extraction, and an alkaline electrolyser |
| **Storage** | Battery, pumped-hydro storage, hydrogen tank |
| **Emissions** | Annual, per-region and a model-horizon CO₂ budget reaching net-zero via carbon capture |

## Scenarios

The regulatory pillars are layered onto the baseline one at a time, so the marginal effect
of each rule can be read off directly.

| Scenario | Description |
| --- | --- |
| **00 · Default** | Least-cost system with no hydrogen regulation (baseline). |
| **01 · Additionality** | Electrolysers may only consume renewable power, and new electrolyser capacity must be backed by new renewable capacity (matched annually). |
| **02 · Temporal correlation** | The renewable-for-hydrogen matching is enforced for every hour rather than annually. |
| **03 · Geographical correlation** | Matching is additionally enforced within each region — full regulatory compliance. |

## Key findings

- **System cost rises 21.1 %** from the unconstrained baseline to full compliance;
  **geographical correlation** contributes the largest single increment.
- **New renewable capacity +29 %** and **electrolyser capacity +52 %**, as the system
  over-builds and adds flexibility to align renewable generation with hydrogen demand.
- The **renewable share** of generation climbs from **45 % to 58.4 %**.
- **Emissions** are largely unchanged until 2040 and reach **net-zero by 2050** through
  carbon capture and storage across all scenarios (the binding CO₂ budget is identical).
- **Inter-regional trade declines** as regional self-sufficiency becomes more valuable.
- **Unmet demand** appears only under the strictest (geographical-correlation) scenario,
  signalling a reliability risk at the tightest matching requirement.

The authors note that the reduced temporal and spatial resolution likely *overestimates*
the cost of compliance — motivating future work at higher resolution.

## The report

The complete term paper — literature review of the EU regulation, methodology and data
assumptions, the full set of regulatory constraints, results and discussion across system
cost, capacity, renewable generation, emissions, trade and reliability, and the conclusion
— is available as a PDF:

➡️ [`report/Report_Effects_of_Regulatory_Rules_for_Renewable_Hydrogen.pdf`](report/Report_Effects_of_Regulatory_Rules_for_Renewable_Hydrogen.pdf)

## Repository contents

| Path | Description |
| --- | --- |
| `report/` | The full term-paper report (PDF). |
| `00_default.jl` … `03_geographic_correlation.jl` | The four scenario models (Julia/JuMP). |
| `helper_functions.jl`, `colors.jl` | Data read-in, result post-processing, and plotting colours. |
| `data/` | All model inputs as CSV — sets, costs, capacities, efficiencies, and demand / capacity-factor profiles. |
| `Project.toml` | The Julia environment used for the study. |
| `results/` | Where each scenario writes its result tables (regenerated from the model). |

## Authors & acknowledgements

- **Toyah Hohenstein**
- **Leonard Schmitz**
- **Paul Weishaupt**
- **Franz Wendel**

Supervised by **Dr. Konstantin Löffler** at TU Berlin (WIP), course *Energy Sector
Modelling (EW MOD)*. The model builds on the open teaching framework of that course.

## Citation

> Hohenstein, T., Schmitz, L., Weishaupt, P., & Wendel, F. (2025).
> *The Effects of Regulatory Rules for Renewable Hydrogen — Examination of the Change in
> Energy System Cost.* Term paper, Energy Sector Modelling (EW MOD),
> Technische Universität Berlin.

A machine-readable citation is provided in [`CITATION.cff`](CITATION.cff).

## License

All rights reserved. This repository is published for documentation and review of an
academic term paper. No license is granted for reuse, redistribution or modification of the
code, data or report without the prior written permission of the authors.
